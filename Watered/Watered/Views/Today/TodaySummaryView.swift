//
//  TodaySummaryView.swift
//  Watered
//
//  Created by Frank Sedivy on 27/08/2026.
//

import SwiftUI

// MARK: - Today Summary View
/// Displays prepared total, goal and progress values without calculating or formatting hydration data.
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
