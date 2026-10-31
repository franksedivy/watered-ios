//
//  HydrationTracker.swift
//  Watered
//
//  Created by Frank Sedivy on 30/06/2026.
//

import Foundation

/// Summarises the supplied drink entries against a daily hydration goal.
///
/// Entries are used as supplied; calendar-day filtering belongs to the caller.
nonisolated struct HydrationTracker {
    /// The logged drinks included in these calculations.
    var entries: [DrinkEntry] = []

    /// The hydration target used to calculate the remaining amount.
    var dailyGoal: HydrationGoal
    
    // MARK: - Total Volume

    /// The total consumed liquid volume, expressed in millilitres.
    ///
    /// Adds each drink's full logged amount after converting it to the base unit.
    var totalVolume: Measurement<UnitVolume> {
        let totalBaseValue = entries.reduce(0.0) { total, entry in
            total + VolumeCalculation.baseValue(from: entry.amount.volume)
        }
        
        return VolumeCalculation.measurement(fromBaseValue: totalBaseValue)
    }
    
    // MARK: - Total Hydration Volume

    /// The sum of the entries' estimated hydration contributions in millilitres.
    ///
    /// Nil if any contribution is unknown. Zero and negative contributions are preserved.
    var totalHydrationVolume: Measurement<UnitVolume>? {
        var totalBaseValue = 0.0
        
        for entry in entries {
            guard let hydrationContributionVolume = entry.hydrationContributionVolume else {
                return nil
            }
            
            totalBaseValue += VolumeCalculation.baseValue(from: hydrationContributionVolume)
        }
        
        return VolumeCalculation.measurement(fromBaseValue: totalBaseValue)
    }
    
    // MARK: - Drink Breakdown

    /// Groups logged drinks by stable identity and orders groups by ID.
    ///
    /// Uses the latest logged name in each group, with UUID string order resolving tied times.
    /// A group has nil hydration contribution if any of its entries has an unknown contribution.
    var drinkBreakdown: [DrinkBreakdown] {
        var breakdowns: [DrinkBreakdown] = []

        let groupedEntries = Dictionary(grouping: entries, by: { entry in
            return entry.drinkID
        })

        for drinkID in groupedEntries.keys.sorted() {
            guard let entriesForDrink = groupedEntries[drinkID] else {
                continue
            }

            let latestEntry = entriesForDrink.max(by: { first, second in
                if first.loggedAt == second.loggedAt {
                    return first.id.uuidString < second.id.uuidString
                }
                return first.loggedAt < second.loggedAt
            })

            guard let latestEntry else {
                continue
            }
            
            var totalBaseValue = 0.0
            
            for entry in entriesForDrink {
                totalBaseValue += VolumeCalculation.baseValue(from: entry.amount.volume)
            }
            
            var totalHydrationBaseValue = 0.0
            var hasUnknownHydrationContribution = false
            
            for entry in entriesForDrink {
                guard let hydrationContributionVolume = entry.hydrationContributionVolume else {
                    hasUnknownHydrationContribution = true
                    break
                }
                
                totalHydrationBaseValue += VolumeCalculation.baseValue(from: hydrationContributionVolume)
            }
            
            let totalHydrationVolume: Measurement<UnitVolume>?
            
            if hasUnknownHydrationContribution {
                totalHydrationVolume = nil
            } else {
                totalHydrationVolume = VolumeCalculation.measurement(
                    fromBaseValue: totalHydrationBaseValue
                )
            }
            
            let breakdown = DrinkBreakdown(
                drinkID: drinkID,
                displayName: latestEntry.displayName,
                totalVolume: VolumeCalculation.measurement(fromBaseValue: totalBaseValue),
                totalHydrationVolume: totalHydrationVolume
            )
            
            breakdowns.append(breakdown)
        }
        
        return breakdowns
    }
    
    // MARK: - Remaining Hydration Volume

    /// The estimated hydration still needed to meet the goal, expressed in millilitres.
    ///
    /// Nil if total hydration is unknown. Returns zero once the goal is met or exceeded.
    var remainingHydrationVolume: Measurement<UnitVolume>? {
        guard let totalHydrationVolume = totalHydrationVolume else {
            return nil
        }
        
        let goalBaseValue = VolumeCalculation.baseValue(from: dailyGoal.volume)
        let totalBaseValue = VolumeCalculation.baseValue(from: totalHydrationVolume)
        let remainingBaseValue = max(goalBaseValue - totalBaseValue, 0)
        
        return VolumeCalculation.measurement(fromBaseValue: remainingBaseValue)
    }
    
    // MARK: - Snapshot

    /// A presentation summary of the current drink counts, totals, goal and grouped drinks.
    ///
    /// Recomputed on access, independently of the immutable catalogue facts saved with each drink.
    var snapshot: HydrationSnapshot {
        HydrationSnapshot(
            drinkCount: entries.count,
            totalVolume: totalVolume,
            totalHydrationVolume: totalHydrationVolume,
            goalVolume: dailyGoal.volume,
            remainingHydrationVolume: remainingHydrationVolume,
            drinkBreakdown: drinkBreakdown
        )
    }
}
