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
    private let onAddDrink: (DrinkEntry, AddDrinkSubmissionMethod) -> Void

    /// The category whose drinks expand inline; nil until the user chooses one.
    @State private var selectedCategoryID: String?
    @State private var selectedDrinkID: String?
    @State private var selectedCaffeineVariant: CaffeineVariant
    @State private var selectedShotCount: Int
    @State private var selectedVolumeValue: Double
    @State private var isShowingPreparationError = false
    @State private var selectedDetent: PresentationDetent = .height(440)
    @State private var isShowingPreparation = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the form from a validated catalogue. Recent shortcuts are hidden for this prototype.
    ///
    /// Starts without a selection and keeps Volume visible while categories expand inline.
    ///
    /// - Parameters:
    ///   - catalogue: Definitions available for new logs.
    ///   - defaultUnit: The app's applied display unit.
    ///   - recentDrinkOptions: Retained for caller compatibility; hidden in this prototype.
    ///   - onAddDrink: Receives a freshly resolved entry and its submission method.
    init(
        catalogue: DrinkCatalogue,
        defaultUnit: LiquidUnit,
        recentDrinkOptions: [RecentDrinkOption],
        onAddDrink: @escaping (DrinkEntry, AddDrinkSubmissionMethod) -> Void
    ) {
        self.catalogue = catalogue
        self.defaultUnit = defaultUnit
        self.onAddDrink = onAddDrink

        _selectedCategoryID = State(initialValue: nil)
        _selectedDrinkID = State(initialValue: nil)
        _selectedCaffeineVariant = State(initialValue: .regular)
        _selectedShotCount = State(initialValue: 1)
        _selectedVolumeValue = State(initialValue: Self.defaultVolumeValue(for: defaultUnit))
    }

    /// A category reveals its drink cards by raising the sheet, not replacing the volume wheel.
    private var expandedDetent: PresentationDetent {
        dynamicTypeSize.isAccessibilitySize ? .large : .height(600)
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.25)
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
            return [150, 200, 250, 300, 330, 400, 500, 600, 750, 1000]
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

    /// Chooses a transparent prototype default and preserves the volume.
    /// Re-tapping the active category keeps any explicit drink/preparation selection.
    private func selectCategory(_ category: DrinkCategory) {
        let drinks = catalogue.activeDrinks(inCategoryID: category.id)
        guard let defaultDrink = AddDrinkCategoryDefaults.drink(in: category.id, from: drinks) else {
            return
        }
        withAnimation(selectionAnimation) {
            if selectedCategoryID != category.id {
                selectedCategoryID = category.id
                selectedDrinkID = defaultDrink.id
                selectedCaffeineVariant = defaultDrink.defaultCaffeineVariant
                selectedShotCount = defaultDrink.shotConfiguration?.defaultCount ?? 1
                isShowingPreparation = false
            }
            // Do not shrink a sheet the user has already expanded manually.
            if selectedDetent != .large {
                selectedDetent = expandedDetent
            }
        }
        wateredLog("Add Drink category changed to \(category.id)")
    }

    /// Selects an active definition and starts from its supported preparation defaults.
    ///
    /// The selected volume remains unchanged when the drink type changes.
    ///
    /// - Parameter definition: The active drink selected within the current category.
    private func selectDrink(_ definition: DrinkDefinition) {
        withAnimation(selectionAnimation) {
            isShowingPreparation = false
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

    /// Keeps the volume wheel outside the scrolling selection sections.
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Volume")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

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

    /// The category row stays in place while the optional details appear below it.
    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories) { category in
                    Button {
                        selectCategory(category)
                    } label: {
                        Label(category.name, systemImage: category.id == "water" ? "drop.fill" : "cup.and.saucer")
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .foregroundStyle(selectedCategoryID == category.id ? .white : categoryTint(category.id))
                            .background(
                                selectedCategoryID == category.id ? categoryTint(category.id) : Color.primary.opacity(0.06),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("addDrinkCategoryScrollView.\(category.id)")
                    .accessibilityAddTraits(selectedCategoryID == category.id ? .isSelected : [])
                    .accessibilityHint("Selects a default drink and reveals more choices.")
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .accessibilityIdentifier("addDrinkCategoryScrollView")
        .fixedSize(horizontal: false, vertical: true)
    }

    private func categoryTint(_ categoryID: String) -> Color {
        categoryID == "coffee" ? .brown : .blue
    }

    private var drinkRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(availableDrinks) { definition in
                    Button {
                        selectDrink(definition)
                    } label: {
                        VStack(spacing: 8) {
                            AddDrinkThumbnail(drinkID: definition.id, categoryID: definition.categoryID)
                                .frame(width: 66, height: 66)
                                .frame(width: 88, height: 88)
                                .background(
                                    selectedDrinkID == definition.id
                                        ? categoryTint(definition.categoryID) : Color.primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 18)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if selectedDrinkID == definition.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white, categoryTint(definition.categoryID))
                                            .padding(5)
                                    }
                                }
                            Text(definition.name)
                                .font(.callout)
                                .foregroundStyle(categoryTint(definition.categoryID))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: 88)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(definition.name)
                    .accessibilityIdentifier("addDrinkTypeScrollView.\(definition.id)")
                    .accessibilityAddTraits(selectedDrinkID == definition.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .accessibilityIdentifier("addDrinkTypeScrollView")
        // Reset the horizontal position when switching to another category.
        .id(selectedCategoryID)
    }

    /// Preparation stays out of the fast path, without removing existing controls.
    @ViewBuilder
    private var preparationSection: some View {
        if let definition = selectedDefinition,
           definition.caffeineOptions.count > 1 || definition.shotConfiguration != nil {
            DisclosureGroup("Preparation", isExpanded: $isShowingPreparation) {
                VStack(alignment: .leading, spacing: 12) {
                    if definition.caffeineOptions.count > 1 {
                        Text("Caffeine").font(.subheadline)
                        Picker("Caffeine", selection: $selectedCaffeineVariant) {
                            ForEach(definition.caffeineOptions, id: \.variant) { option in
                                Text(option.variant.rawValue.capitalized).tag(option.variant)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("addDrinkCaffeinePicker")
                    }
                    if let configuration = definition.shotConfiguration {
                        Text("Shots").font(.subheadline)
                        Picker("Shots", selection: $selectedShotCount) {
                            ForEach(configuration.supportedCounts.sorted(), id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("addDrinkShotPicker")
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedCategoryID == nil ? "Type" : "Select your drink")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 20)
                categoryRow

                if selectedCategoryID != nil {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            drinkRow
                            preparationSection
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .transition(.opacity)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 16)
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
        .presentationDetents([.height(440), .height(600), .large], selection: $selectedDetent)
        .onChange(of: isShowingPreparation) { _, isExpanded in
            if isExpanded {
                withAnimation(selectionAnimation) { selectedDetent = .large }
            }
        }
        .onChange(of: dynamicTypeSize) { _, size in
            if size.isAccessibilitySize { selectedDetent = .large }
        }
        .onAppear {
            if dynamicTypeSize.isAccessibilitySize { selectedDetent = .large }
        }
    }
}

#if DEBUG
#Preview("Recents hidden") {
    let catalogue = try! DrinkCatalogueLoader().load()
    let entry = DrinkPreviewData.entry(drinkID: "still-water", amount: DrinkAmount(value: 300, unit: .milliliters))
    AddDrinkView(
        catalogue: catalogue,
        defaultUnit: .milliliters,
        recentDrinkOptions: WateredStore(entries: [entry]).recentDrinkOptions(in: catalogue),
        onAddDrink: { entry, method in wateredLog("Preview submitted \(entry) via \(method)") }
    )
}

#Preview("Neutral selection") {
    AddDrinkView(
        catalogue: try! DrinkCatalogueLoader().load(),
        defaultUnit: .milliliters,
        recentDrinkOptions: [],
        onAddDrink: { entry, method in wateredLog("Preview submitted \(entry) via \(method)") }
    )
}
#endif

