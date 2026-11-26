//
//  PersistentAppSettings.swift
//  Watered
//
//  Created by Frank Sedivy on 07/09/2026.
//

import Foundation
import SwiftData

// MARK: - Persistent App Settings
/// Stores settings as primitive values and stable unit identifiers.
/// Mapping restores the goal’s recorded value and unit without display-unit conversion;
/// unrecognised unit identifiers return nil. Saving belongs to AppSettingsPersistence.
@Model
final class PersistentAppSettings {
    var id: String
    var displayUnitID: String
    var dailyGoalValue: Double
    var dailyGoalUnitID: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = "appSettings",
        displayUnitID: String,
        dailyGoalValue: Double,
        dailyGoalUnitID: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayUnitID = displayUnitID
        self.dailyGoalValue = dailyGoalValue
        self.dailyGoalUnitID = dailyGoalUnitID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    convenience init(appSettings: AppSettings) {
        self.init(
            displayUnitID: appSettings.displayUnit.persistenceIdentifier,
            dailyGoalValue: appSettings.dailyHydrationGoal.amount.value,
            dailyGoalUnitID: appSettings.dailyHydrationGoal.amount.unit.persistenceIdentifier
        )
    }
    
    func appSettings() -> AppSettings? {
        guard let displayUnit = LiquidUnit(persistenceIdentifier: displayUnitID),
              let dailyGoalUnit = LiquidUnit(persistenceIdentifier: dailyGoalUnitID)
        else {
            return nil
        }
        
        return AppSettings(
            displayUnit: displayUnit,
            dailyHydrationGoal: HydrationGoal(
                amount: DrinkAmount(
                    value: dailyGoalValue,
                    unit: dailyGoalUnit
                )
            )
        )
    }
}
