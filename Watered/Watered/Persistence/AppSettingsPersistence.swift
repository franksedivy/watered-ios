//
//  AppSettingsPersistence.swift
//  Watered
//
//  Created by Frank Sedivy on 27/09/2026.
//

import Foundation
import SwiftData

/// Coordinates persistence operations for app settings and hydration goal history.
@MainActor
enum AppSettingsPersistence {
    /// Loads existing settings or commits first-run settings and their initial goal record together.
    ///
    /// Existing settings return without saving pending edits or adding missing goal history.
    /// For first-run creation, pending edits are saved before inserting either record. A failed
    /// creation save rolls back both insertions while preserving those earlier committed edits.
    /// Initial fetch and pending-edit save failures propagate without rollback here.
    ///
    /// - Parameters:
    ///   - defaults: Settings to use when no persisted settings exist.
    ///   - context: The context used to fetch and save records.
    ///   - date: The timestamp shared by initial settings and their goal record.
    /// - Returns: The existing or newly saved settings record.
    /// - Throws: A persistence error if fetching or saving fails.
    static func loadOrCreate(
        defaults: AppSettings,
        in context: ModelContext,
        at date: Date = Date()
    ) throws -> PersistentAppSettings {
        let descriptor = FetchDescriptor<PersistentAppSettings>()
        
        if let existingSettings = try context.fetch(descriptor).first {
            return existingSettings
        }
        
        // Save unrelated pending edits before starting this operation,
        // so a rollback cannot discard those edits.
        if context.hasChanges {
            try context.save()
        }
        
        let settings = PersistentAppSettings(appSettings: defaults)
        settings.createdAt = date
        settings.updatedAt = date
        
        let initialGoal = HydrationGoalChange(
            goal: defaults.dailyHydrationGoal,
            changedAt: date,
            source: .appDefault
        )
        
        context.insert(settings)
        context.insert(PersistentHydrationGoalChange(change: initialGoal))
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        
        wateredLog("Persistence created initial settings and default goal history.")
        return settings
    }
    
    /// Saves a changed goal and appends its history record in one save.
    ///
    /// An unchanged numeric value and goal unit return without saving pending edits or adding history.
    /// For a changed goal, pending edits are saved before mutating settings and inserting history.
    /// Failure of that preliminary save propagates without rollback here. Failure of the goal save
    /// rolls back the settings update and new history record, preserving earlier committed edits.
    ///
    /// - Parameters:
    ///   - goal: The final goal to commit; comparison uses its numeric value and unit, not converted volume.
    ///   - source: How the goal was established.
    ///   - settings: The settings record already managed by the supplied context.
    ///   - context: The context used to save both records.
    ///   - date: The timestamp for this committed goal change.
    /// - Returns: True if the goal changed and was saved; false if it was unchanged.
    /// - Throws: A persistence error from saving pending edits or committing the goal and history.
    static func saveGoal(
        _ goal: HydrationGoal,
        source: HydrationGoalSource,
        settings: PersistentAppSettings,
        in context: ModelContext,
        at date: Date = Date()
    ) throws -> Bool {
        let goalUnitID = goal.amount.unit.persistenceIdentifier
        
        guard settings.dailyGoalValue != goal.amount.value
                || settings.dailyGoalUnitID != goalUnitID else {
            return false
        }
        
        // Protect unrelated pending edits from this operation's rollback.
        if context.hasChanges {
            try context.save()
        }
        
        let change = HydrationGoalChange(
            goal: goal,
            changedAt: date,
            source: source
        )
        
        settings.dailyGoalValue = goal.amount.value
        settings.dailyGoalUnitID = goalUnitID
        settings.updatedAt = date
        context.insert(PersistentHydrationGoalChange(change: change))
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        
        wateredLog("Persistence saved goal \(goal.amount.formatted) and its history record.")
        return true
    }
    
    /// Saves a changed display unit without modifying the goal or its history.
    ///
    /// An unchanged unit returns without saving pending edits or invoking the callback.
    /// For a changed unit, pending edits are saved before mutation; failure of that preliminary
    /// save propagates without rollback here. Callback or unit-save failures roll back the context,
    /// restoring the previous unit and timestamp while preserving earlier committed edits.
    ///
    /// - Parameters:
    ///   - unit: The selected display unit.
    ///   - settings: The settings record managed by the supplied context.
    ///   - context: The context used to save the settings.
    ///   - date: The timestamp for the settings update.
    ///   - beforeSave: An optional action run after mutation and before saving.
    /// - Returns: True if the unit changed and was saved; otherwise false.
    /// - Throws: An error from saving pending edits, the callback, or saving settings.
    static func saveDisplayUnit(
        _ unit: LiquidUnit,
        settings: PersistentAppSettings,
        in context: ModelContext,
        at date: Date = Date(),
        beforeSave: () throws -> Void = {}
    ) throws -> Bool {
        let unitID = unit.persistenceIdentifier
        
        guard settings.displayUnitID != unitID else {
            return false
        }
        
        // Protect unrelated pending edits from this operation's rollback.
        if context.hasChanges {
            try context.save()
        }
        
        settings.displayUnitID = unitID
        settings.updatedAt = date
        
        do {
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        
        wateredLog("Persistence saved display unit \(unit.rawValue).")
        return true
    }
}
