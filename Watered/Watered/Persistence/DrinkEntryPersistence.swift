//
//  DrinkEntryPersistence.swift
//  Watered
//
//  Created by Frank Sedivy on 04/10/2026.
//

import Foundation
import SwiftData

/// Coordinates persistence operations for drink entries.
@MainActor
enum DrinkEntryPersistence {
    enum SaveError: Error { case duplicateEntry }

    /// Commits a new drink and any eligible frozen Health export intents together.
    ///
    /// Existing context edits are saved before checking for a duplicate entry. Failures in
    /// that initial save or duplicate lookup propagate without this method rolling back.
    /// After insertion, capture, callback or save failures roll back the supplied context;
    /// previously committed edits remain saved.
    ///
    /// - Parameters:
    ///   - entry: The drink to persist.
    ///   - context: The context used to insert and save the record.
    ///   - healthClient: When supplied, captures eligibility from the committed sync preference
    ///     and current write grants. Omission saves only the drink; no Health write occurs here.
    ///   - beforeSave: An optional action after insertion and export capture, before committing.
    /// - Throws: A persistence, capture or callback error, or `SaveError.duplicateEntry`.
    /// - Important: The caller updates in-memory state and success analytics only after return.
    static func save(
        _ entry: DrinkEntry,
        in context: ModelContext,
        healthClient: (any HealthKitClient)? = nil,
        beforeSave: () throws -> Void = {}
    ) throws {
        if context.hasChanges { try context.save() }
        let id = entry.id
        guard try context.fetchCount(FetchDescriptor<PersistentDrinkEntry>(predicate: #Predicate { $0.id == id })) == 0 else {
            throw SaveError.duplicateEntry
        }
        let persistentEntry = PersistentDrinkEntry(drinkEntry: entry)
        
        context.insert(persistentEntry)
        
        do {
            if let healthClient { try HealthExportPersistence.capture(entry, client: healthClient, in: context) }
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
    
    /// Commits local removal and returns identifiers the caller can remove from visible history.
    ///
    /// Empty input returns without saving pending edits or invoking the callback. Otherwise,
    /// pending edits are committed first. Health-aware deletion re-fetches current records in
    /// a fresh context, cancels never-started exports and hides drinks with possible Health writes.
    /// Their details remain stored until the executor completes cleanup and commits final purge.
    /// Without Health tracking, records are deleted directly in the supplied context.
    ///
    /// - Parameters:
    ///   - entries: Stored drink records belonging to the supplied context.
    ///   - context: The records' context; Health-aware deletion uses its container for a fresh transaction.
    ///   - tracksHealthExports: Whether to preserve cleanup intent for possible Health writes.
    ///   - beforeSave: An optional action run after marking records for deletion, before saving the deletion.
    /// - Returns: The requested identifiers after a successful commit, or an empty set for empty input.
    ///   Returned identifiers do not imply that retained details or Health samples have been purged.
    /// - Throws: An error from saving pending edits, fetching, preparing deletion, the callback or saving.
    ///   Preparation, callback and deletion-save failures roll back the deletion context;
    ///   earlier pending-edit saves and fetch failures are outside that rollback boundary.
    /// - Important: This operation performs no Health I/O and does not update the in-memory store.
    static func delete(
        _ entries: [PersistentDrinkEntry],
        in context: ModelContext,
        tracksHealthExports: Bool = false,
        beforeSave: () throws -> Void = {}
    ) throws -> Set<UUID> {
        guard entries.isEmpty == false else {
            return[]
        }
        
        if context.hasChanges {
            try context.save()
        }
        
        if tracksHealthExports {
            // The UI may have registered older export rows. Read current possible-write state
            // in a fresh transaction so a cached pending row cannot erase an in-flight intent.
            let transaction = ModelContext(context.container)
            transaction.autosaveEnabled = false
            let ids = Set(entries.map(\.id))
            let current = try transaction.fetch(FetchDescriptor<PersistentDrinkEntry>()).filter { ids.contains($0.id) }
            do {
                for entry in current {
                    try HealthExportPersistence.prepareDeletion(entry, in: transaction, at: Date())
                }
                try beforeSave()
                try transaction.save()
            } catch {
                transaction.rollback()
                throw error
            }
            return ids
        }

        // Capture identifiers before saving invalidates the deleted records.
        let deletedIDs = Set(entries.map { entry in
            entry.id
        })
        
        do {
            for entry in entries {
                context.delete(entry)
            }
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            wateredLog("Drink deletion failed.")
            throw error
        }
        
        wateredLog("Deleted \(entries.count) saved drink entries")
        return deletedIDs
    }
}
