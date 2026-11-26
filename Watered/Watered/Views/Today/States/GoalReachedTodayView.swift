//
//  GoalReachedTodayView.swift
//  Watered
//
//  Created by Frank Sedivy on 28/08/2026.
//

import SwiftUI

// MARK: - Goal Reached Today View
/// Displays the goal-reached message and a prepared hydration summary.
/// TodayView determines whether the goal has been reached.
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
