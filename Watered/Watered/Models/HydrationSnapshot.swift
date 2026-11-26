//
//  HydrationSnapshot.swift
//  Watered
//
//  Created by Frank Sedivy on 04/07/2026.
//

import Foundation

/// Captures hydration totals, goal and breakdown at one point in time, preserving unknown estimates.
nonisolated struct HydrationSnapshot {
    // MARK: - Stored Values
    
    let drinkCount: Int
    let totalVolume: Measurement<UnitVolume>
    let totalHydrationVolume: Measurement<UnitVolume>?
    let goalVolume: Measurement<UnitVolume>
    let remainingHydrationVolume: Measurement<UnitVolume>?
    let drinkBreakdown: [DrinkBreakdown]
    
    // MARK: - Hydration Progress

    /// Returns hydration divided by the goal, without clamping to the display range.
    /// Unknown hydration returns nil; a nonpositive goal returns zero.
    var hydrationProgress: Double? {
        guard let totalHydrationVolume = totalHydrationVolume else {
            return nil
        }
        
        let totalBaseValue = VolumeCalculation.baseValue(from: totalHydrationVolume)
        let goalBaseValue = VolumeCalculation.baseValue(from: goalVolume)
        
        guard goalBaseValue > 0 else {
            return 0
        }
        
        return totalBaseValue / goalBaseValue
    }
    
    /// Clamps known hydration progress to 0...1 for display, preserving nil for unknown hydration.
    var clampedHydrationProgress: Double? {
        guard let hydrationProgress = hydrationProgress else {
            return nil
        }
        
        return min(max(hydrationProgress,0), 1)
    }
}
