//
//  InProgressTodayView.swift
//  Watered
//
//  Created by Frank Sedivy on 28/08/2026.
//

import SwiftUI

// MARK: - In Progress Today View

// Purpose:
// Displays the normal Today screen state once more than one drink has been logged.
//
// Input:
// Accepts the number of logged drinks and HydrationSummaryViewData.
//
// Returns:
// A SwiftUI view containing the drink count message, hydration summary and drink
// breakdown.
//
// UI role:
// Keeps the main active Today state separate from TodayView. TodayView remains
// responsible for choosing the current screen mode, while this view handles the
// layout for the in-progress state.

struct InProgressTodayView: View {
    let drinkCount: Int
    let summary: HydrationSummaryViewData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("You consumed \(drinkCount) drinks:")
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

        InProgressTodayView(
            drinkCount: entries.count,
            summary: summary
        )
        .padding()
        .background(Color.blue)
}
#endif
