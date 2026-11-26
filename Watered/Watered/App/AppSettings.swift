//
//  AppSettings.swift
//  Watered
//
//  Created by Frank Sedivy on 07/09/2026.
//

import Foundation

// MARK: - App Settings
/// Carries the preferred display unit and hydration goal independently of SwiftData.
nonisolated struct AppSettings {
    let displayUnit: LiquidUnit
    let dailyHydrationGoal: HydrationGoal
    
    // MARK: - Defaults
    /// Creates a 2700 ml goal with US fluid ounces for US measurement systems,
    /// otherwise milliliters. The supplied locale controls only the display unit.
    static func defaults(for locale: Locale = .current) -> AppSettings {
        let displayUnit: LiquidUnit
        
        switch locale.measurementSystem {
        case .us:
            displayUnit = .usFluidOunces
        default:
            displayUnit = .milliliters
        }
        
        return AppSettings(
            displayUnit: displayUnit,
            dailyHydrationGoal: HydrationGoal(
                amount: DrinkAmount(value: 2700, unit: .milliliters)
            )
        )
    }
}
