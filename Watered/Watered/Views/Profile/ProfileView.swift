//
//  ProfileView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

// MARK: - Profile View

/// Presents display-unit preferences and a draft daily hydration goal.
///
/// The parent persists unit changes immediately and commits the final goal on dismissal.
struct ProfileView: View {
    
    /// The parent's applied unit, used to format volumes without changing their stored value.
    @Binding var displayUnit: LiquidUnit
    
    /// The parent's goal draft, committed only when the Profile sheet closes.
    @Binding var dailyHydrationGoal: HydrationGoal
    
    #if DEBUG
    // MARK: - Developer Actions

    /// Requests history deletion; nil hides the control and a thrown error presents feedback.
    var onDeleteAllDrinks: (() throws -> Void)? = nil
    
    /// Controls confirmation before deleting the entire drink history.
    @State private var isConfirmingDrinkReset = false
    
    /// Presents an error when the parent cannot complete the deletion.
    @State private var isShowingDrinkResetError = false
    
    /// Dismisses the Profile sheet after a successful drink-history reset.
    @Environment(\.dismiss) private var dismiss
    #endif
    
    /// Formats the goal in the selected display unit without mutating the goal draft.
    private var formattedDailyHydrationGoal: String {
        VolumeFormatter().wholeNumberString(
            from: dailyHydrationGoal.volume,
            displayedAs: displayUnit
        )
    }

    /// Bridges the goal draft to the stepper while preserving its original storage unit.
    private var dailyHydrationGoalValue: Binding<Double> {
        Binding(
            get: {
                dailyHydrationGoal.amount.value
            },
            set: { newValue in
                    dailyHydrationGoal = HydrationGoal(
                        amount: DrinkAmount(
                            value: newValue,
                            unit: dailyHydrationGoal.amount.unit
                        )
                    )
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display units") {
                    Picker("Volume unit", selection: $displayUnit) {
                        ForEach(LiquidUnit.allCases) { liquidUnit in
                            Text(liquidUnit.rawValue)
                                .tag(liquidUnit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("displayUnitPicker")
                    .accessibilityHint("Changes the volume unit used across Watered.")
                }
                Section("Hydration goal") {
                    Stepper(
                        value: dailyHydrationGoalValue,
                        in: 500...5000,
                        step: 100
                    ) {
                        Text("Daily goal: \(formattedDailyHydrationGoal)")
                            .accessibilityIdentifier("dailyHydrationGoalText")
                    }
                    .accessibilityIdentifier("dailyHydrationGoalStepper")
                    .accessibilityHint("Changes the daily hydration goal used by Today.")
                }
                
                #if DEBUG
                if let deleteAllDrinks = onDeleteAllDrinks {
                    Section("Developer Tools") {
                        Button("Delete all drinks", role: .destructive) {
                            isConfirmingDrinkReset = true
                        }
                        .accessibilityIdentifier("deleteAllDrinksButton")
                    }
                    .confirmationDialog(
                        "Delete all drinks?",
                        isPresented: $isConfirmingDrinkReset,
                        titleVisibility: .visible
                    ) {
                        Button("Delete all drinks", role: .destructive) {
                            do {
                                try deleteAllDrinks()
                                dismiss()
                            } catch {
                                wateredLog("Profile reset failed: \(error.localizedDescription)")
                                isShowingDrinkResetError = true
                            }
                        }
                        .accessibilityIdentifier("confirmDeleteAllDrinksButton")
                        
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This permanently deletes your entire drink history. Are you sure?")
                    }
                    .alert(
                        "Could not delete drinks",
                        isPresented: $isShowingDrinkResetError
                    ) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("Your drink history could not be deleted.")
                    }
                }
                #endif
            }
            .navigationTitle("Profile")
            .accessibilityIdentifier("profileScreen")
        }
    }
}

#Preview {
    ProfileView(
        displayUnit: .constant(.milliliters),
        dailyHydrationGoal: .constant(
            HydrationGoal(
                amount: DrinkAmount(value: 2700, unit: .milliliters)
            )
        )
    )
}
