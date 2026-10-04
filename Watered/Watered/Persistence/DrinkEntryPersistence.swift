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
    
    /// Inserts a drink and explicitly saves the context.
    ///
    /// - Parameters:
    ///   - entry: The drink to persist.
    ///   - context: The context used to insert and save the record.
    ///   - beforeSave: An optional action run after insertion and before saving
    /// - Throws: Ann error from the callback or save, after rolling back pending changes.
    /// - Important: Rollback affects all pending changes in the supplied context. This operation does not update app state
    ///              or record analytics
    static func save(
        _ entry: DrinkEntry,
        in context: ModelContext,
        beforeSave: () throws -> Void = {}
    ) throws {
        let persistentEntry = PersistentDrinkEntry(drinkEntry: entry)
        
        wateredLog("Persistence insert started for dirnk entry \(entry.id)")
        context.insert(persistentEntry)
        
        do {
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        
        wateredLog("Persistence save succeeded for dink entry \(entry.id)")
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
        beforeSave: () throws -> Void = {}
    ) throws -> Set<UUID> {
        guard entries.isEmpty == false else {
            return[]
        }
        
        if context.hasChanges {
            try context.save()
        }
        
        // Capture identifiers before saving invalidates the deleted records.
        let deletedIDs = Set(entries.map { entry in
            entry.id
        })
        
        for entry in entries {
            context.delete(entry)
        }
        
        do {
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            wateredLog("Drink deletion failed: \(error.localizedDescription)")
            throw error
        }
        
        wateredLog("Deleted \(entries.count) saved drink entries")
        return deletedIDs
    }
}
