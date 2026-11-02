//
//  GoalReachedTodayView.swift
//  Watered
//
//  Created by Frank Sedivy on 28/08/2026.
//

import SwiftUI

// MARK: - Goal Reached Today View
//
// Purpose:
// Displays the Today screen state shown once the user reaches their hydration goal.
//
// Input:
// Accepts HydrationSummaryViewData, which already contains the formatted total,
// goal, progress and drink breakdown rows needed by the UI.
//
// Returns:
// A SwiftUI view containing the goal-reached message, hydration summary adn drink
// breakdown.
//
// UI role:
// Keeps the goal-reached presentation separate from TodayView. TodayView decides
// when the user has reached the goal; this view only handles how that state is
// shown.
struct GoalReachedTodayView: View {
    let summary: HydrationSummaryViewData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("You hit your goal! Fully watered.")
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
            amount: DrinkAmount(value: 2200, unit: .milliliters),
            date: Date()
        ),
        DrinkPreviewData.entry(
            drinkID: "cappuccino",
            amount: DrinkAmount(value: 600, unit: .milliliters),
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

    GoalReachedTodayView(summary: summary)
        .padding()
        .background(Color.blue)
}
#endif
