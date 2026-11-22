import Foundation
import SwiftData

@MainActor
enum HealthExportPersistence {
    static func isEnabled(in context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<PersistentHealthSyncPreference>()).first?.isEnabled == true
    }

    /// Called synchronously inside the entry transaction; no awaits or permission prompts.
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

    /// #110 consumes retained delete intents. No cleanup I/O or purge of possibly-written data here.
    static func prepareDeletion(_ entry: PersistentDrinkEntry, in context: ModelContext, at date: Date) throws {
        let id = entry.id
        let records = try context.fetch(FetchDescriptor<PersistentHealthExport>(predicate: #Predicate { $0.entryID == id }))
        var needsCleanup = false
        for record in records {
            if record.mayHaveWritten {
                needsCleanup = true
                record.operation = "delete"
                // Preserve in-flight state until the outstanding callback settles.
                if record.status != "inFlight" { record.status = "pending" }
                record.nextAttemptAt = nil
            } else {
                context.delete(record)
            }
        }
        if needsCleanup { entry.deletedAt = date } else { context.delete(entry) }
    }
}
