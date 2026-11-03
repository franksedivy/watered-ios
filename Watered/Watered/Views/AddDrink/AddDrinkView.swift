//
//  AddDrinkView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

/// Presents category, drink type, preparation and volume before submitting a new entry.
///
/// The parent owns persistence, success analytics, error recovery and sheet dismissal.
struct AddDrinkView: View {
    private let catalogue: DrinkCatalogue
    private let defaultUnit: LiquidUnit
    private let recentDrinkOptions: [RecentDrinkOption]
    private let onAddDrink: (DrinkEntry, AddDrinkSubmissionMethod) -> Void

    /// The category whose drinks expand inline; nil until the user chooses one.
    @State private var selectedCategoryID: String?
    @State private var selectedDrinkID: String?
    @State private var selectedCaffeineVariant: CaffeineVariant
    @State private var selectedShotCount: Int
    @State private var selectedVolumeValue: Double
    @State private var isShowingPreparationError = false

    /// Creates the form from a validated catalogue and currently available shortcuts.
    ///
    /// Starts without a selection and keeps Volume visible while categories expand inline.
    ///
    /// - Parameters:
    ///   - catalogue: Definitions available for new logs.
    ///   - defaultUnit: The app's applied display unit.
    ///   - recentDrinkOptions: Shortcuts filtered against the current catalogue.
    ///   - onAddDrink: Receives a freshly resolved entry and its submission method.
    init(
        catalogue: DrinkCatalogue,
        defaultUnit: LiquidUnit,
        recentDrinkOptions: [RecentDrinkOption],
        onAddDrink: @escaping (DrinkEntry, AddDrinkSubmissionMethod) -> Void
    ) {
        self.catalogue = catalogue
        self.defaultUnit = defaultUnit
        self.recentDrinkOptions = recentDrinkOptions
        self.onAddDrink = onAddDrink

        _selectedCategoryID = State(initialValue: nil)
        _selectedDrinkID = State(initialValue: nil)
        _selectedCaffeineVariant = State(initialValue: .regular)
        _selectedShotCount = State(initialValue: 1)
        _selectedVolumeValue = State(initialValue: Self.defaultVolumeValue(for: defaultUnit))
    }

    /// Reserves space for Type and Volume, plus shortcuts when available.
    private var preferredPresentationDetent: PresentationDetent {
        return .fraction(recentDrinkOptions.isEmpty ? 0.68 : 0.82)
    }

    /// Categories containing active drinks, preserving the catalogue's display order.
    ///
    /// Empty categories and categories containing only retired drinks are hidden.
    private var availableCategories: [DrinkCategory] {
        return catalogue.orderedCategories.filter { category in
            return !catalogue.activeDrinks(inCategoryID: category.id).isEmpty
        }
    }

    /// Active definitions in the selected category, preserving their configured order.
    private var availableDrinks: [DrinkDefinition] {
        guard let categoryID = selectedCategoryID else {
            return []
        }
        return catalogue.activeDrinks(inCategoryID: categoryID)
    }

    /// The active selected drink, or nil when the category has no valid selection.
    private var selectedDefinition: DrinkDefinition? {
        availableDrinks.first { definition in
            definition.id == selectedDrinkID
        }
    }

    /// The existing shared volume presets, expressed in the applied app unit.
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

    /// Supplies the shared starting volume for the applied unit.
    private static func defaultVolumeValue(for unit: LiquidUnit) -> Double {
        switch unit {
        case .milliliters: return 330
        case .usFluidOunces: return 12
        case .imperialFluidOunces: return 8
        }
    }

    /// Inserts a category's drinks after its pill and waits for a drink selection.
    ///
    /// Preserves the volume. Tapping the selected category also leaves
    /// its current drink and preparation untouched.
    ///
    /// - Parameter category: The catalogue category selected in the Type row.
    private func selectCategory(_ category: DrinkCategory) {
        guard category.id != selectedCategoryID,
              !catalogue.activeDrinks(inCategoryID: category.id).isEmpty else {
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedCategoryID = category.id
            selectedDrinkID = nil
            selectedCaffeineVariant = .regular
            selectedShotCount = 1
        }
        wateredLog("Add Drink category changed to \(category.id)")
    }

    /// Selects an active definition and starts from its supported preparation defaults.
    ///
    /// The selected volume remains unchanged when the drink type changes.
    ///
    /// - Parameter definition: The active drink selected within the current category.
    private func selectDrink(_ definition: DrinkDefinition) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDrinkID = definition.id
            selectedCaffeineVariant = definition.defaultCaffeineVariant
            selectedShotCount = definition.shotConfiguration?.defaultCount ?? 1
        }
        wateredLog("Add Drink selection changed to \(definition.id)")
    }

    /// Resolves the selected drink once before handing the entry to the submission boundary.
    private func submitDrink() {
        guard let definition = selectedDefinition else {
            isShowingPreparationError = true
            return
        }
        let draft = AddDrinkDraft(
            drinkID: definition.id,
            volumeValue: selectedVolumeValue,
            unit: defaultUnit,
            caffeineVariant:
                selectedCaffeineVariant,
            shotCount: definition.shotConfiguration == nil ? nil : selectedShotCount
        )
        do {
            let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
            let entry = try draft.drinkEntry(using: resolver)
            wateredLog("Add Drink submitted \(entry.drinkID) at \(entry.amount.formatted)")
            onAddDrink(entry, .form)
        } catch {
            wateredLog("Add Drink preparation failed: \(error.localizedDescription)")
            isShowingPreparationError = true
        }
    }

    /// Repeats a shortcut using current rules and a new entry identity.
    ///
    /// - Parameter option: The tapped shortcut, selected by identity rather than label.
    private func submitRecentDrink(_ option: RecentDrinkOption) {
        do {
            let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
            let entry = try option.drinkEntry(using: resolver)
            wateredLog("Recent drink submitted: \(entry.drinkID)")
            onAddDrink(entry, .recent)
        } catch {
            wateredLog("Recent drink preparation failed: \(error.localizedDescription)")
            isShowingPreparationError = true
        }
    }

    /// Keeps the volume wheel outside the scrolling selection sections.
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Volume")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)

            Picker("Volume", selection: $selectedVolumeValue) {
                ForEach(volumeOptions, id: \.self) { volumeOption in
                    Text("\(Int(volumeOption)) \(defaultUnit.rawValue)").tag(volumeOption)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 216)
            .accessibilityIdentifier("addDrinkVolumePicker")
            .accessibilityLabel("Drink volume")
            .accessibilityValue("\(Int(selectedVolumeValue)) \(defaultUnit.rawValue)")
            .accessibilityHint("Adjusts the amount for the drink being added.")
            .onChange(of: selectedVolumeValue) { previousValue, newValue in
                wateredLog(
                    "Add Drink volume changed from \(previousValue) to \(newValue) "
                    + "\(defaultUnit.rawValue)"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Expands drink choices directly after their category without replacing its pill.
    private var typeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories) { category in
                    AddDrinkPillButton(
                        label: category.name,
                        isSelected: selectedCategoryID == category.id,
                        accessibilityIdentifier: "addDrinkCategoryScrollView.\(category.id)",
                        onSelect: { selectCategory(category) }
                    )

                    if selectedCategoryID == category.id {
                        ForEach(availableDrinks) { definition in
                            AddDrinkPillButton(
                                label: definition.name,
                                isSelected: selectedDrinkID == definition.id,
                                accessibilityIdentifier: "addDrinkTypeScrollView.\(definition.id)",
                                onSelect: { selectDrink(definition) }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .accessibilityIdentifier("addDrinkTypeScrollView")
    }

    var body: some View {
        NavigationStack {
            Form {
                if !recentDrinkOptions.isEmpty {
                    Section("Recent drinks") {
                        AddDrinkPillRow(
                            options: recentDrinkOptions,
                            accessibilityIdentifier: "addDrinkRecentsScrollView",
                            optionLabel: { option in return option.label },
                            onSelect: { option in submitRecentDrink(option) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }

                Section("Type") {
                    typeRow
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                if let definition = selectedDefinition {
                    if definition.caffeineOptions.count > 1 {
                        Section("Preparation") {
                            Picker("Caffeine", selection: $selectedCaffeineVariant) {
                                ForEach(definition.caffeineOptions, id: \.variant) { option in
                                    Text(option.variant.rawValue.capitalized).tag(option.variant)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("addDrinkCaffeinePicker")
                        }
                    }
                    if let configuration = definition.shotConfiguration {
                        Section("Shots") {
                            Picker("Shots", selection: $selectedShotCount) {
                                ForEach(configuration.supportedCounts.sorted(), id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("addDrinkShotPicker")
                        }
                    }
                }

            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                volumeSection
            }
            .accessibilityIdentifier("addDrinkScreen")
            .navigationTitle("Add drink")
            .navigationSubtitle("Now, change time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: submitDrink) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .disabled(selectedDefinition == nil)
                    .accessibilityLabel("Save drink")
                    .accessibilityHint("Adds the selected drink and closes the Add Drink form.")
                    .accessibilityIdentifier("addDrinkSubmitButton")
                }
            }
            .alert("Could not prepare your drink", isPresented: $isShowingPreparationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This selection could not be prepared. Choose a drink and try again.")
            }
            .onAppear {
                wateredLog("Add Drink sheet appeared with unit \(defaultUnit.rawValue)")
            }
        }
        .presentationDetents([preferredPresentationDetent, .large])
    }
}

#if DEBUG
#Preview("With Recent Drinks") {
    let catalogue = try! DrinkCatalogueLoader().load()
    let entry = DrinkPreviewData.entry(drinkID: "still-water", amount: DrinkAmount(value: 300, unit: .milliliters))
    AddDrinkView(
        catalogue: catalogue,
        defaultUnit: .milliliters,
        recentDrinkOptions: WateredStore(entries: [entry]).recentDrinkOptions(in: catalogue),
        onAddDrink: { entry, method in wateredLog("Preview submitted \(entry) via \(method)") }
    )
}

#Preview("No Recent Drinks") {
    AddDrinkView(
        catalogue: try! DrinkCatalogueLoader().load(),
        defaultUnit: .milliliters,
        recentDrinkOptions: [],
        onAddDrink: { entry, method in wateredLog("Preview submitted \(entry) via \(method)") }
    )
}
#endif
