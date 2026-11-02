//
//  FirstDrinkTodayView.swift
//  Watered
//
//  Created by Frank Sedivy on 28/08/2026.
//

import SwiftUI

// MARK: - First Drink Today View
//
// Purpose:
// Displays the Today screen state shown after the user logs their first drink.
//
// Input:
// Accepts HydrationSummaryViewData, which already contains the formatted text,
// progress values and drink breakdown rows needed by the UI.
//
// Returns:
// A SwiftUI view containing the first-drink message, summary and drink
// breakdown.
//
// UI role:
// Keeps the frist-drink presentation separate from TodayView. TodayView
// decides which state is active' this view only knows how to display the
// first-drink state.
struct FirstDrinkTodayView: View {
    let summary: HydrationSummaryViewData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("You downed your first drink! Nice")
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            
            TodaySummaryView(summary: summary)
            TodayDrinkBreakdownView(rows: summary.drinkBreakdownRows)
        }
    }
}

#if DEBUG
#Preview {
    let goal = HydrationGoal(
            amount: DrinkAmount(value: 2700, unit: .milliliters)
        )

        let entries = [
            DrinkPreviewData.entry(
                drinkID: "still-water",
                amount: DrinkAmount(value: 1200, unit: .milliliters),
                date: Date()
            ),
            DrinkPreviewData.entry(
                drinkID: "sparkling-water",
                amount: DrinkAmount(value: 660, unit: .milliliters),
                date: Date()
            ),
            DrinkPreviewData.entry(
                drinkID: "espresso",
                amount: DrinkAmount(value: 50, unit: .milliliters),
                date: Date()
            )
        ]

        let tracker = HydrationTracker(
            entries: entries,
            dailyGoal: goal
        )

        let summary = HydrationSummaryViewData(
            snapshot: tracker.snapshot,
            volumeFormatter: VolumeFormatter(),
            progressFormatter: ProgressFormatter(),
            displayUnit: .milliliters
        )
    
        FirstDrinkTodayView(
            summary: summary
        )
        .padding()
        .background(Color.yellow)
}
#endif
