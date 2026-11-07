//
//  HydrationSummaryViewData.swift
//  Watered
//
//  Created by Frank Sedivy on 13/08/2026.
//

import Foundation

// MARK: - Drink Breakdown Hydration Impact Style

/// A presentation category based on estimated hydration contribution relative to liquid consumed.
nonisolated enum HydrationImpactStyle {
    /// The estimated contribution is at least 80% of consumed volume.
    case positive

    /// The estimated contribution is at least 30% but below 80% of consumed volume.
    case reduced

    /// The estimated contribution is below 30%, including zero and negative values.
    case negative

    /// The hydration contribution is unknown.
    case unknown
}

extension HydrationImpactStyle {
    // MARK: - Initialisation

    /// Maps a known hydration contribution fraction to its presentation category.
    ///
    /// - Parameter hydrationImpactProgress: Contribution divided by consumed volume,
    ///   where 1.0 means 100%.
    nonisolated init(hydrationImpactProgress: Double) {
        if hydrationImpactProgress >= 0.8 {
            self = .positive
        } else if hydrationImpactProgress >= 0.3 {
            self = .reduced
        } else {
            self = .negative
        }
    }
}

/// Display-ready text and styling for one grouped drink row.
nonisolated struct DrinkBreakdownViewData {
    /// The logged identity used to distinguish this row.
    let drinkID: String

    /// The formatted liquid amount and display name, preserving the name's casing.
    let consumedText: String

    /// The formatted hydration percentage, or an unknown-contribution message.
    let hydrationImpactText: String

    /// The semantic category used to style the hydration impact text.
    let hydrationImpactStyle: HydrationImpactStyle
}

/// Formatted totals, progress and grouped drink rows for the Today screen.
nonisolated struct HydrationSummaryViewData {
    /// The raw liquid total with its descriptive label.
    let totalText: String

    /// The raw liquid total without a descriptive label.
    let totalAmountText: String

    /// The hydration goal with its descriptive label.
    let goalText: String

    /// The hydration goal without a descriptive label.
    let goalAmountText: String

    /// The labelled remaining hydration amount, or an unknown-hydration message.
    let remainingText: String

    /// The labelled number of logged drinks.
    let drinkCountText: String

    /// The hydration percentage clamped at zero, or an unknown-progress message.
    let progressText: String

    /// The unclamped hydration progress, or nil when hydration is unknown.
    let actualProgressValue: Double?

    /// Progress clamped between zero and one for display; zero when hydration is unknown.
    let visualProgressValue: Double

    /// The formatted drink groups in the order supplied by the snapshot.
    let drinkBreakdownRows: [DrinkBreakdownViewData]
    
    // MARK: - Initialisation
    
    /// Formats calculated hydration values for presentation.
    ///
    /// Uses snapshot totals without recalculating the contributions of logged drinks.
    ///
    /// - Parameters:
    ///   - snapshot: The calculated counts, volumes, goal and grouped drinks.
    ///   - volumeFormatter: Formats volumes in the selected display unit.
    ///   - progressFormatter: Formats progress and hydration contribution percentages.
    ///   - displayUnit: The unit used for displayed volumes; defaults to millilitres.
    init(
        snapshot: HydrationSnapshot,
        volumeFormatter: VolumeFormatter,
        progressFormatter: ProgressFormatter,
        displayUnit: LiquidUnit = .milliliters
    ) {
        let totalLiquid = volumeFormatter.wholeNumberString(
            from: snapshot.totalVolume,
            displayedAs: displayUnit
        )
        let goal = volumeFormatter.wholeNumberString(
            from: snapshot.goalVolume,
            displayedAs: displayUnit
        )
        
        totalText = "Total liquid: \(totalLiquid)"
        totalAmountText = totalLiquid
        goalText = "Hydration goal: \(goal)"
        goalAmountText = goal
        drinkCountText = "Drinks logged: \(snapshot.drinkCount)"
        
        if let remainingHydrationVolume = snapshot.remainingHydrationVolume {
            let remainingHydration = volumeFormatter.wholeNumberString(
                from: remainingHydrationVolume,
                displayedAs: displayUnit
            )
            remainingText = "Remaining hydration: \(remainingHydration)"
        } else {
            remainingText = "Remaining hydration: Unknown"
        }
        
        if let hydrationProgress = snapshot.hydrationProgress {
            let textProgress = max(hydrationProgress, 0)
            
            progressText = progressFormatter.percentageString(from: textProgress)
            actualProgressValue = hydrationProgress
            visualProgressValue = snapshot.clampedHydrationProgress ?? 0.0
        } else {
            progressText = "Hydration progress unknown"
            actualProgressValue = nil
            visualProgressValue = 0.0
        }
        
        drinkBreakdownRows = snapshot.drinkBreakdown.map { drinkBreakdown in
            let amount = volumeFormatter.wholeNumberString(
                from: drinkBreakdown.totalVolume,
                displayedAs: displayUnit
            )
            let consumedText = "\(amount) of \(drinkBreakdown.displayName)"
            
            let hydrationImpactText: String
            let hydrationImpactStyle: HydrationImpactStyle
            
            if let totalHydrationVolume = drinkBreakdown.totalHydrationVolume {
                let totalLiquidBaseValue = VolumeCalculation.baseValue(from: drinkBreakdown.totalVolume)
                let totalHydrationBaseValue = VolumeCalculation.baseValue(from: totalHydrationVolume)
                
                let hydrationImpactProgress = totalHydrationBaseValue / totalLiquidBaseValue
                let hydrationImpact = progressFormatter.contributionPercentageString(from: hydrationImpactProgress)
                
                hydrationImpactText = "Hydration impact: \(hydrationImpact)"
                hydrationImpactStyle = HydrationImpactStyle(hydrationImpactProgress: hydrationImpactProgress)
            } else {
                hydrationImpactText = "Hydration impact: Unknown"
                hydrationImpactStyle = .unknown
            }
            
            return DrinkBreakdownViewData(
                drinkID: drinkBreakdown.drinkID,
                consumedText: consumedText,
                hydrationImpactText: hydrationImpactText,
                hydrationImpactStyle: hydrationImpactStyle
            )
        }
    }
}
