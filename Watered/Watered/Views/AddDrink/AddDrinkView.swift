//
//  AddDrinkView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

// MARK: - Add Drink View
//
// Purpose:
// Presents Watered's first real Add Drink flow.
//
// Input:
// Accepts the current display unit, recent-drink shortcuts, and an
// onAddDrink closure from the parent view.
//
// Returns:
// A SwiftUI sheet view that can submit either a selected recent drink or a new
// drink built from the form's selected type and volume.
//
// UI role:
// This view owns the temporary Add Drink form state. It does not store drinks
// itself; submitted entries are handed back to the parent through onAddDrink.
struct AddDrinkView: View {
    // MARK: - Actions

    /// Hands the submitted drink and its interactions method to the parent.
    private let onAddDrink: (DrinkEntry, AddDrinkSubmissionMethod) -> Void

    // Purpose:
    // Stores the app-level display unit when the Add Drink form opens.
    //
    // Input:
    // Supplied by WateredTabView from the temporary display unit selected in
    // Profile
    //
    // UI role:
    // Lets Add Drink defaults its volume selection to the same unit Today
    // is using.
    private let defaultUnit: LiquidUnit

    // MARK: - Initialisation

    init(
        defaultUnit: LiquidUnit,
        recentDrinkOptions: [RecentDrinkOption],
        onAddDrink: @escaping (DrinkEntry, AddDrinkSubmissionMethod) -> Void
    ) {
        self.defaultUnit = defaultUnit
        self.recentDrinkOptions = recentDrinkOptions
        self.onAddDrink = onAddDrink
        _selectedVolumeValue = State(
            initialValue: AddDrinkView.defaultVolumeValue(for: defaultUnit)
        )
    }

    // MARK: - Form State
    //
    // Purpose: Stores the drink tyep currently selected in the Add Drink form.
    //
    // UI role:
    // Lets the form remember the user's selected drink type before the real
    // DrinkEntry creation step exists.
    //
    // Notes:
    // This is local form state. It updates Today only after the user submits the form.
    @State private var selectedDrinkType: DrinkType = .water

    // Purpose: Stores the selected volume amount inside the Add Drink form.
    //
    // Input:
    // Gives the form a concrete volume value before the real DrinkEntry creation
    // step exists.
    @State private var selectedVolumeValue: Double


    // MARK: - Recent Drink Options
    //
    // Purpose:
    // Stores the recent-drink labels available to the Add Drink sheet.
    //
    // Input:
    // Supplied during initilsiation. Defaults to temporary placehoder data until
    // persistence-backed recent drinks exist.
    private let recentDrinkOptions: [RecentDrinkOption]

    // Purpose:
    // Decides whether the Recent drinks section should be visible.
    //
    // Returns:
    // 'true' when the Add Drink sheet has at least one recent-drink option.
    //
    // UI role:
    // Precents the sheet from showing an empty Recent drinks section when there
    // is no recent-drink data available.
    private var hasRecentDrinkOptions: Bool {
        return recentDrinkOptions.isEmpty == false
    }

    // Purpose:
    // Converts structured recent-drink options into labels for the pill row.
    //
    // Returns:
    // A list of user-facing labels such as "300 ml of Water".
    //
    // UI role:
    // Keeps AddDrinkPillRow simple for now by giving it strings, while
    // AddDrinkView still retains the structured recent-drink data needed for
    // direct submissions.
    private var recentDrinkLabels: [String] {
        return recentDrinkOptions.map { recentDrinkOption in
            recentDrinkOption.label
        }
    }

    // MARK: - Drink Type Options
    //
    // Purpose:
    // Provides the display labels for drink types shown in the Add Drink sheet.
    //
    // Returns:
    // A list of drink type names based on the model's supported DrinkType values.
    //
    // UI role:
    // Lets the Type section display horizontally scrolling selectable pills while
    // still using DrinkType as the source of truth.
    private var drinkTypeLabels: [String] {
        DrinkType.allCases.map { drinkType in
            drinkType.rawValue
        }
    }

    // MARK: - Volume Options
    //
    // Purpose: Provides the first predefined volume options for the Add Drink form.
    //
    // Returns: A list of common drink volumes in the currently selected unit.
    //
    // UI role:
    // Keeps the Volume picker simple while avoiding free numeric input for the first
    // real Add Drink flow.
    private var volumeOptions: [Double] {
        switch defaultUnit {
        case .milliliters:
            return [150, 200, 250, 300, 330, 500, 600, 750, 1000]
        case .usFluidOunces:
            return [6, 8, 10, 12, 16, 20, 24, 32]
        case .imperialFluidOunces:
            return [5, 8, 10, 12, 16, 20, 24, 32]
        }
    }

    // Purpose: Provides the default volumes for the form's selected unit.
    //
    // Input: Accepts the unit that Add Drink recieved from the app-level setting.
    //
    // Returns: A sensible starting volume from the predefined options
    private static func defaultVolumeValue(for unit: LiquidUnit) -> Double {
        switch unit {
        case .milliliters:          return 330
        case .usFluidOunces:        return 12
        case .imperialFluidOunces:  return 8
        }
    }

    // MARK: - Submission
    
    /// Creates a drink entry from the current form selections and submits it to the parent.
    ///
    /// Uses the selected drink type, volume, and display unit to create an `AddDrinkDraft`.
    /// Passes the resulting entry to `onAddDrink` with the `.form` submission method.
    ///
    /// - Important: The parent handles persistence, success analytics, and sheet dismissal.
    private func submitDrink() {
        let draft = AddDrinkDraft(
            drinkType: selectedDrinkType,
            volumeValue: selectedVolumeValue,
            unit: defaultUnit
        )

        let drinkEntry = draft.drinkEntry()

        wateredLog("Add Drink submitted \(selectedDrinkType.rawValue) at \(Int(selectedVolumeValue)) \(defaultUnit.rawValue)")
        onAddDrink(drinkEntry, .form)
    }

    /// Submits a new drink entry from the matching recent-drink shortcut.
    ///
    /// Finds the option matching the tapped label and creates a new entry from its values.
    /// Passes the entry to `onAddDrink` with the `.recent` submission method, without requiring
    /// form confirmation. If no option matches, logs the failure and returns without submitting.
    ///
    /// - Parameter label: The label of the recent-drink shortcut that was tapped.
    /// - Important: The parent handles persistence, success analytics, and sheet dismissal.
    private func submitRecentDrink(label: String) {
        guard let recentDrinkOption = recentDrinkOptions.first(where: { recentDrinkOption in
            recentDrinkOption.label == label
        }) else {
            wateredLog("Could not submit recent drink because no option matched label: \(label)")
            return
        }

        let drinkEntry = recentDrinkOption.drinkEntry()

        wateredLog("Recent drink submitted: \(recentDrinkOption.label)")
        onAddDrink(drinkEntry, .recent)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                if hasRecentDrinkOptions {
                    Section("Recent drinks") {
                        AddDrinkPillRow(
                            labels: recentDrinkLabels,
                            accessibilityIdentifier: "addDrinkRecentsScrollView",
                            onSelect: { selectedLabel in
                                submitRecentDrink(label: selectedLabel)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                Section("Drink type") {
                    AddDrinkPillRow(
                        labels: drinkTypeLabels,
                        selectedLabel: selectedDrinkType.rawValue,
                        accessibilityIdentifier: "addDrinkTypeScrollView",
                        onSelect: { selectedLabel in
                            guard let selectedDrinkType = DrinkType(rawValue: selectedLabel)
                            else {
                                return
                            }

                            wateredLog("Add Drink type changed to \(selectedDrinkType.rawValue)")
                            self.selectedDrinkType = selectedDrinkType
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                Section("Volume") {
                    Picker("Volume", selection: $selectedVolumeValue) {
                        ForEach(volumeOptions, id: \.self) { volumeOption in
                            Text("\(Int(volumeOption)) \(defaultUnit.rawValue)")
                                .tag(volumeOption)
                        }
                    }
                    .pickerStyle(.wheel)
                    .accessibilityIdentifier("addDrinkVolumePicker")
                    .accessibilityLabel("Drink volume")
                    .accessibilityValue("\(Int(selectedVolumeValue)) \(defaultUnit.rawValue)")
                    .accessibilityHint("Adjusts the amount for the drink being added.")
                    .onChange(of: selectedVolumeValue) { previousValue, newValue in
                        wateredLog("Add Drink volume changed from \(Int(previousValue)) \(defaultUnit.rawValue) to \(Int(newValue)) \(defaultUnit.rawValue)")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .accessibilityIdentifier("addDrinkScreen")
            .navigationTitle("Add drink")
            .navigationSubtitle("Now, change time")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action :submitDrink) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Save drink")
                    .accessibilityHint("Adds the selected drink and closes the Add Drink form.")
                    .accessibilityIdentifier("addDrinkSubmitButton")
                }
            }
            .onAppear {
                wateredLog(
                    "Add Drink sheet appeared with unit \(defaultUnit.rawValue) and default volume \(Int(selectedVolumeValue)) \(defaultUnit.rawValue)"
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("With Recent Drinks") {
    AddDrinkView(
        defaultUnit: .milliliters,
        recentDrinkOptions: [
            RecentDrinkOption(
                drinkType: .water,
                volumeValue: 300,
                unit: .milliliters
            )
        ],
        onAddDrink: { drinkEntry, method in
            wateredLog("Preview submitted drink entry: \(drinkEntry)")
        }
    )
}

#Preview("No Recent Drinks") {
    AddDrinkView(
        defaultUnit: .milliliters,
        recentDrinkOptions: [],
        onAddDrink: { drinkEntry, method in
            wateredLog("Preview submitted drink via \(method): \(drinkEntry)")
        }
    )
}
