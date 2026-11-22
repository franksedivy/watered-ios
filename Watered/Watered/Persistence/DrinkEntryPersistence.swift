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

    /// Inserts a drink and explicitly saves the context.
    ///
    /// - Parameters:
    ///   - entry: The drink to persist.
    ///   - context: The context used to insert and save the record.
    ///   - beforeSave: An optional action run after insertion and before saving
    /// - Throws: An error from the callback or save, after rolling back pending changes.
    /// - Important: Existing edits are saved first. The drink and eligible frozen export intents
    /// commit together; rollback creates no success state or analytics.
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
    
    /// Deletes stored drinks and returns their indentifiers after saving succeeds.
    ///
    /// Pending changes are saved before deletion so rollback cannot discard them.
    ///
    /// - Parameters:
    ///   - entries: Stored drink records belonging to the supplied context.
    ///   - context: The context used to delete and save the records.
    ///   - beforeSave: An optional action run after marking records for deletion, before saving the deletion.
    /// - Returns: The deleted identifiers, or an empty set when no records are supplied.
    /// - Throws: An error from saving pending changes, the callback, or deletion saving.
    /// - Important: This operation does not update the in-memory store.
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
