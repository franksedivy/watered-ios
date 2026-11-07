//
//  AddDrinkActionButton.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

// MARK: - Add Drink Action Button
//
// Purpose: Shows the primary add-drink action used near the app tab bar.
// Input: Accepts tap and recent-drink actions from the parent view.
// Returns: A small circular SwiftUI button.
//
// UI role:
// This button exists because Watered needs a prominent add-drink action near the
// tab bar, similar in placement to Apple's search affordance, while keeping the
// actual tab bar native.
struct AddDrinkActionButton: View {
    // MARK: - Actions

    // Purpose: Stores the action that runs when the button is tapped.
    // Input: Supplied by the parent view that owns the add-drink sheet state.
    private let onTap: () -> Void
    private let displayUnit: LiquidUnit
    private let recentDrinks: [RecentDrinkOption]
    private let onSelectRecent: (RecentDrinkOption) -> Void

    // MARK: - Initialisation
    init(
        recentDrinks: [RecentDrinkOption] = [],
        displayUnit: LiquidUnit = .milliliters,
        onSelectRecent: @escaping (RecentDrinkOption) -> Void = { _ in },
        onTap: @escaping () -> Void
    ) {
        self.displayUnit = displayUnit
        self.recentDrinks = Array(recentDrinks.prefix(3))
        self.onSelectRecent = onSelectRecent
        self.onTap = onTap
    }

    // MARK: - Body
    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .regular))
                .frame(width: 48, height: 48)
                
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Add drink")
        .accessibilityIdentifier("addDrinkActionButton")
        .accessibilityHint("Opens the Add Drink form. Touch and hold for recent drinks.")
        .contextMenu {
            Section("Recent drinks") {
                if recentDrinks.isEmpty {
                    Button("No recent drinks yet", action: {})
                        .disabled(true)
                } else {
                    ForEach(recentDrinks) { option in
                        Button {
                            onSelectRecent(option)
                        } label: {
                            Text(option.label(displayedAs: displayUnit))
                        }
                        .accessibilityIdentifier("recentDrink.\(option.drinkID)")
                        .accessibilityHint("Adds this drink again now.")
                    }
                }
            }
        }
    }
}

#Preview {
    AddDrinkActionButton(onTap: {})
}

