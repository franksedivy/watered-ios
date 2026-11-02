//
//  TodaySummaryView.swift
//  Watered
//
//  Created by Frank Sedivy on 27/08/2026.
//

import SwiftUI

// MARK: - Today Summary View
//
// Purpose:
// Displays the main hydration summary for the Today screen.
//
// Input:
// Accepts HydrationSummaryViewData, which contains display-ready text and visual
// progress values prepared outside this view.
//
// Returns:
// A SwiftUI view containing the total liquid amount, daily goal text and
// hydration prgoress display.
//
// UI role:
// Keeps the main Today summary presentation separate from TodayView. This view
// does not calculate totals, goals, remaining hydration or progress.
struct TodaySummaryView: View {
    let summary: HydrationSummaryViewData
    
    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Text(summary.totalAmountText)
                .font(.system(size: 96, weight: .light))
                .accessibilityIdentifier("todayTotalAmountText")
            
            Text("Daily goal: \(summary.goalAmountText)")
                .font(.title3)
            
            TodayProgressView(
                progressText: summary.progressText,
                visualProgressValue: summary.visualProgressValue
            )
        }
    }
}

#if DEBUG
#Preview {
    TodaySummaryView(
        summary: HydrationSummaryViewData(
            snapshot: HydrationTracker(
                entries: [
                    DrinkPreviewData.entry(
                        drinkID: "still-water",
                        amount: DrinkAmount(value: 300, unit: .milliliters),
                        date: Date()
                    )
                ],
                dailyGoal: HydrationGoal(
                    amount: DrinkAmount(value: 2700, unit: .milliliters)
                )
            ).snapshot,
            volumeFormatter: VolumeFormatter(),
            progressFormatter: ProgressFormatter()
        )
    )
    .padding()
    .background(Color.blue)
}
#endif
