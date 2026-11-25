import Foundation
import SwiftData

/// Owns local sync-preference commits and stages export lifecycle changes without Health I/O.
/// Capture, deletion preparation and purge leave saving and rollback to their caller.
@MainActor
enum HealthExportPersistence {
    static func isEnabled(in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<PersistentHealthSyncPreference>()).first?.isEnabled == true
    }

    /// Stages frozen per-type export intents alongside a newly inserted drink.
    /// Reads the committed preference through a fresh context and checks current write grants;
    /// invalid mappings create invalid records, while unknown, zero and ineligible types add no work.
    /// Runs synchronously without permission prompts or Health writes. The caller must commit
    /// the drink and intents together, or roll back the supplied context if capture or saving fails.
    static func capture(_ entry: DrinkEntry, client: any HealthKitClient, in context: ModelContext) throws {
        guard try isEnabled(in: ModelContext(context.container)) else { return }
        let eligible = Set(HealthWriteType.allCases.filter { client.authorization(for: $0) == .authorized })
        let results = HealthSampleMapping.resolve(entry, eligibleTypes: eligible)
        for type in HealthWriteType.allCases {
            switch results[type] {
            case .sample(let specification):
                context.insert(PersistentHealthExport(entryID: entry.id, type: type,
                    payload: try JSONEncoder().encode(specification)))
            case .invalid:
                context.insert(PersistentHealthExport(entryID: entry.id, type: type, payload: nil, invalid: true))
            default: break
            }
        }
    }

    /// Commits the switch independently of system permission. Never scans old drinks.
    /// Pending context edits are saved before reading the preference, even for an unchanged choice.
    /// Initial save/fetch failures propagate without rollback here. Once the preference is changed,
    /// callback or save failures roll back the context, preserving earlier committed edits.
    static func setEnabled(_ enabled: Bool, in context: ModelContext, at date: Date = Date(),
                           beforeSave: () throws -> Void = {}) throws {
        if context.hasChanges { try context.save() }
        let preference = try context.fetch(FetchDescriptor<PersistentHealthSyncPreference>()).first
            ?? PersistentHealthSyncPreference()
        guard preference.isEnabled != enabled else { return }
        if preference.modelContext == nil { context.insert(preference) }
        preference.isEnabled = enabled
        if enabled { preference.enabledAt = date }
        do {
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Include queued uploads: they may finish while the confirmation is open.
    /// Entries without eligible or possible writes need only local-deletion wording.
    static func needsCleanupNotice(for entryIDs: Set<UUID>, in context: ModelContext) throws -> Bool {
        guard !entryIDs.isEmpty else { return false }
        return try context.fetch(FetchDescriptor<PersistentHealthExport>()).contains {
            entryIDs.contains($0.entryID) && ($0.mayHaveWritten ||
                ($0.operation == "upload" && ["pending", "inFlight", "authorizationBlocked"].contains($0.status)))
        }
    }

    /// Stages cancellation of never-started uploads and cleanup for possibly-written types.
    /// Marks the drink hidden when cleanup is needed; otherwise stages its immediate deletion.
    /// Already-hidden drinks are left unchanged, including existing retry state.
    /// Does not save or perform Health cleanup: the caller owns the atomic commit and rollback
    /// of these mutations before reporting local deletion or updating visible history.
    static func prepareDeletion(_ entry: PersistentDrinkEntry, in context: ModelContext, at date: Date) throws {
        // Repeated deletion/reset must not reopen completed cleanup or reset its backoff.
        guard entry.deletedAt == nil else { return }
        let id = entry.id
        let records = try context.fetch(FetchDescriptor<PersistentHealthExport>(predicate: #Predicate { $0.entryID == id }))
        var needsCleanup = false
        for record in records {
            if record.mayHaveWritten {
                needsCleanup = true
                record.operation = "delete"
                record.attemptCount = 0
                record.failureCategory = nil
                // Preserve in-flight state until the outstanding callback settles.
                if record.status != "inFlight" { record.status = "pending" }
                record.nextAttemptAt = nil
            } else {
                context.delete(record)
            }
        }
        if needsCleanup { entry.deletedAt = date } else { context.delete(entry) }
    }

    /// Stages removal of hidden drinks whose remaining export records all acknowledge deletion.
    /// Hidden drinks with no remaining export records are also eligible for purge.
    /// Only the serialized executor calls this, with no outstanding I/O for these records.
    /// The caller owns saving and rollback, committing purge with the final cleanup acknowledgement
    /// or in a recovery transaction for previously completed cleanup. This method does not save.
    static func purgeCompletedDeletions(in context: ModelContext) throws {
        let deleted = try context.fetch(FetchDescriptor<PersistentDrinkEntry>(predicate: #Predicate { $0.deletedAt != nil }))
        for entry in deleted {
            let id = entry.id
            let records = try context.fetch(FetchDescriptor<PersistentHealthExport>(predicate: #Predicate { $0.entryID == id }))
            guard records.allSatisfy({ $0.operation == "delete" && $0.status == "succeeded" }) else { continue }
            for record in records { context.delete(record) }
            context.delete(entry)
        }
    }

}
