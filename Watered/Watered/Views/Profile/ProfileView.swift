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

    /// Closes Profile through the parent's existing goal-commit-on-dismiss boundary.
    @Environment(\.dismiss) private var dismiss
    
    var analytics: any AnalyticsClient = NoOpAnalyticsClient()

    /// Optional so standalone previews do not require a live HealthKit dependency.
    @Environment(HealthAuthorizationController.self)
    private var healthAuthorization: HealthAuthorizationController?

    @Environment(HealthExportCoordinator.self)
    private var healthExport: HealthExportCoordinator?

    #if DEBUG
    // MARK: - Developer Actions

    /// Requests history deletion; nil hides the control and a thrown error presents feedback.
    var onDeleteAllDrinks: (() throws -> Void)? = nil
    var needsHealthCleanupNoticeForReset: () throws -> Bool = { false }
    @State private var showsHealthCleanupNotice = false
    
    /// Controls confirmation before deleting the entire drink history.
    @State private var isConfirmingDrinkReset = false
    
    /// Presents an error when the parent cannot complete the deletion.
    @State private var isShowingDrinkResetError = false
    
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
                Section("Syncing") {
                    if let healthAuthorization, let healthExport {
                        Section {
                            NavigationLink("Apple Health") {
                                HealthSyncView(authorization: healthAuthorization, coordinator: healthExport, analytics: analytics)
                            }
                        }
                    }

                    if let healthExport {
                        HealthCleanupSection(coordinator: healthExport)
                    }
                }

                #if DEBUG
                if healthExport != nil || onDeleteAllDrinks != nil {
                    Section("Developer Tools") {
                        if let healthExport {
                            NavigationLink("Verify HealthKit export") {
                                DebugHealthExportView(coordinator: healthExport)
                            }
                        }
                        if let deleteAllDrinks = onDeleteAllDrinks {
                            Button("Delete all drinks", role: .destructive) {
                                do {
                                    showsHealthCleanupNotice = try needsHealthCleanupNoticeForReset()
                                    isConfirmingDrinkReset = true
                                } catch { isShowingDrinkResetError = true }
                            }
                            .accessibilityIdentifier("deleteAllDrinksButton")
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
                                        wateredLog("Profile reset failed.")
                                        isShowingDrinkResetError = true
                                    }
                                }
                                .accessibilityIdentifier("confirmDeleteAllDrinksButton")
                        
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                if showsHealthCleanupNotice {
                                    Text("This removes all drinks from Watered. Apple Health cleanup may finish later if permission is unavailable. Your settings and goal history stay unchanged. This cannot be undone.")
                                } else {
                                    Text("This removes all drinks from Watered. Your settings and goal history stay unchanged. This cannot be undone.")
                                }
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
                    }
                }
                #endif
            }
            .navigationTitle("Profile")
            .accessibilityIdentifier("profileScreen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("profileDoneButton")
                }
            }
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
