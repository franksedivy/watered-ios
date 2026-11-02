//
//  TodayDrinkBreakdownView.swift
//  Watered
//
//  Created by Frank Sedivy on 27/08/2026.
//

import SwiftUI

// MARK: - Today Drink Breakdown View

/// Displays grouped liquid totals and hydration impact on the Today screen.
///
/// Receives text and styling prepared by HydrationSummaryViewData.
struct TodayDrinkBreakdownView: View {
    /// The formatted drink groups, shown in their supplied order.
    let rows: [DrinkBreakdownViewData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.drinkID) { drinkBreakdownRow in
                VStack(alignment: .leading, spacing: 2) {
                    Text(drinkBreakdownRow.consumedText)
                    
                    Text(drinkBreakdownRow.hydrationImpactText)
                        .font(.caption)
                        .fontWeight(fontWeight(for: drinkBreakdownRow.hydrationImpactStyle))
                        .foregroundStyle(foregroundStyle(for: drinkBreakdownRow.hydrationImpactStyle))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    
    /// Chooses the colour for a row's hydration impact text.
    ///
    /// - Parameter style: The presentation category prepared by the view-data layer.
    /// - Returns: Green for positive, orange for reduced, red for negative,
    ///   or secondary for unknown.
    private func foregroundStyle(for style: HydrationImpactStyle) -> Color {
        switch style {
        case .positive:
            return .green
        case .reduced:
            return .orange
        case .negative:
            return .red
        case .unknown:
            return .secondary
        }
    }
    
    // MARK: - Hydration Impact Styling

    /// Chooses the emphasis for a row's hydration impact text.
    ///
    /// - Parameter style: The presentation category prepared by the view-data layer.
    /// - Returns: Semibold for reduced impact, bold for negative impact, or regular otherwise.
    private func fontWeight(for style: HydrationImpactStyle) -> Font.Weight {
        switch style {
        case .positive:
            return .regular
        case .reduced:
            return .semibold
        case .negative:
            return .bold
        case .unknown:
            return .regular
        }
    }
}

#Preview {
    TodayDrinkBreakdownView(
        rows: [
            DrinkBreakdownViewData(
                drinkID: "still-water",
                consumedText: "1200 ml of Water",
                hydrationImpactText: "Hydration impact: 100%",
                hydrationImpactStyle: .positive
            ),
            DrinkBreakdownViewData(
                drinkID: "beer",
                consumedText: "330 ml of Beer",
                hydrationImpactText: "Hydration impact: 50%",
                hydrationImpactStyle: .reduced
            )
        ]
    )
    .padding()
    .background(Color.blue)
}
