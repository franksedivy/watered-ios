//
//  DrinkEntryPersistence.swift
//  Watered
//
//  Created by Frank Sedivy on 04/10/2026.
//

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
    
}
