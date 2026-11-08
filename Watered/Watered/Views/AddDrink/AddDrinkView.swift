//
//  AddDrinkView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

/// An unsaved form retained by the app shell only for the current session.
struct AddDrinkSheetDraft: Equatable {
    var categoryID: String?
    var drinkID: String?
    var caffeineVariant: CaffeineVariant
    var shotCount: Int
    var volumeValue: Double
    var unit: LiquidUnit
}

/// Presents category, drink type, preparation and volume before submitting a new entry.
///
/// The parent owns persistence, success analytics, error recovery and sheet dismissal.
struct AddDrinkView: View {
    @Binding private var retainedDraft: AddDrinkSheetDraft?
    private let catalogue: DrinkCatalogue
    private let defaultUnit: LiquidUnit
    private let onAddDrink: (DrinkEntry, AddDrinkSubmissionMethod) -> Void

    /// The category whose drinks expand inline; nil until the user chooses one.
    @State private var selectedCategoryID: String?
    @State private var selectedDrinkID: String?
    @State private var selectedCaffeineVariant: CaffeineVariant
    @State private var selectedShotCount: Int
    @State private var volumeSelection: AddDrinkVolumeSelection
    @State private var isShowingPreparationError = false
    @State private var selectedDetent: PresentationDetent = .height(480)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the form from a validated catalogue. Recent shortcuts are hidden for this prototype.
    ///
    /// Restores an unsaved session draft, otherwise starts without a selection.
    ///
    /// - Parameters:
    ///   - catalogue: Definitions available for new logs.
    ///   - defaultUnit: The app's applied display unit.
    ///   - recentDrinkOptions: Retained for caller compatibility; hidden in this prototype.
    ///   - retainedDraft: Session-only storage owned by the app shell.
    ///   - onAddDrink: Receives a freshly resolved entry and its submission method.
    init(
        catalogue: DrinkCatalogue,
        defaultUnit: LiquidUnit,
        recentDrinkOptions: [RecentDrinkOption],
        retainedDraft: Binding<AddDrinkSheetDraft?> = .constant(nil),
        onAddDrink: @escaping (DrinkEntry, AddDrinkSubmissionMethod) -> Void
    ) {
        self.catalogue = catalogue
        self.defaultUnit = defaultUnit
        self._retainedDraft = retainedDraft
        self.onAddDrink = onAddDrink

        let saved = retainedDraft.wrappedValue
        _selectedCategoryID = State(initialValue: saved?.categoryID)
        _selectedDrinkID = State(initialValue: saved?.drinkID)
        _selectedCaffeineVariant = State(initialValue: saved?.caffeineVariant ?? .regular)
        _selectedShotCount = State(initialValue: saved?.shotCount ?? 1)
        _volumeSelection = State(initialValue: AddDrinkVolumeSelection(
            value: saved?.volumeValue ?? AddDrinkVolumeSelection.defaultValue(for: defaultUnit),
            unit: saved?.unit ?? defaultUnit,
            canApplyServingDefault: saved == nil
        ))
        let definition = saved?.drinkID.flatMap { catalogue.drink(withID: $0) }
        let hasPreparation = definition.map { $0.caffeineOptions.count > 1 || $0.shotConfiguration != nil } ?? false
        _selectedDetent = State(initialValue: saved?.categoryID == nil
            ? .height(480) : .height(hasPreparation ? 720 : 600))
    }

    private var currentDraft: AddDrinkSheetDraft {
        AddDrinkSheetDraft(
            categoryID: selectedCategoryID, drinkID: selectedDrinkID,
            caffeineVariant: selectedCaffeineVariant, shotCount: selectedShotCount,
            volumeValue: volumeSelection.value, unit: volumeSelection.unit
        )
    }

    /// Leaves room for the selected drink's controls without reserving an empty preparation panel.
    private var expandedDetent: PresentationDetent {
        if dynamicTypeSize.isAccessibilitySize { return .large }
        return hasPreparationOptions ? .height(720) : .height(600)
    }

    private var hasPreparationOptions: Bool {
        guard let definition = selectedDefinition else { return false }
        return definition.caffeineOptions.count > 1 || definition.shotConfiguration != nil
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

    /// Chooses a prototype default, applying its serving only when volume is untouched.
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
                volumeSelection.applyServingDefault(defaultDrink.defaultVolume)
                selectedCaffeineVariant = defaultDrink.defaultCaffeineVariant
                selectedShotCount = defaultDrink.shotConfiguration?.defaultCount ?? 1
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
    /// Deliberately selected and restored volumes remain unchanged when the drink type changes.
    ///
    /// - Parameter definition: The active drink selected within the current category.
    private func selectDrink(_ definition: DrinkDefinition) {
        withAnimation(selectionAnimation) {
            selectedDrinkID = definition.id
            volumeSelection.applyServingDefault(definition.defaultVolume)
            selectedCaffeineVariant = definition.defaultCaffeineVariant
            selectedShotCount = definition.shotConfiguration?.defaultCount ?? 1
            if selectedDetent != .large {
                selectedDetent = expandedDetent
            }
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
            volumeValue: volumeSelection.value,
            unit: volumeSelection.unit,
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

    /// A bottom-anchored wheel with bounded drawing and hit area, independent of preparation height.
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Volume")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Picker("Volume", selection: Binding(
                get: { volumeSelection.displayValue(in: defaultUnit) },
                set: { volumeSelection.select($0, displayedAs: defaultUnit) }
            )) {
                ForEach(volumeSelection.options(in: defaultUnit), id: \.self) { volumeOption in
                    Text(volumeSelection.label(for: volumeOption, in: defaultUnit)).tag(volumeOption)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 216)
            .clipped()
            .accessibilityIdentifier("addDrinkVolumePicker")
            .accessibilityLabel("Drink volume")
            .accessibilityValue(volumeSelection.label(
                for: volumeSelection.displayValue(in: defaultUnit), in: defaultUnit
            ))
            .accessibilityHint("Adjusts the amount for the drink being added.")
            .onChange(of: volumeSelection) { previousValue, newValue in
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
        switch categoryID {
        case "coffee": return .brown
        case "tea": return .mint
        default: return .blue
        }
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
                                    Color.primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 18)
                                )
                                .overlay {
                                    if selectedDrinkID == definition.id {
                                        RoundedRectangle(cornerRadius: 18)
                                            .strokeBorder(categoryTint(definition.categoryID), lineWidth: 2)
                                    }
                                }
                            Text(definition.name)
                                .font(.callout)
                                .foregroundStyle(.primary)
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

    /// Shows only the preparation choices supported by the selected definition.
    @ViewBuilder
    private var preparationSection: some View {
        if let definition = selectedDefinition, hasPreparationOptions {
            VStack(spacing: 12) {
                if definition.caffeineOptions.contains(where: { $0.variant == .regular }),
                   definition.caffeineOptions.contains(where: { $0.variant == .decaf }) {
                    Toggle(isOn: Binding(
                        get: { selectedCaffeineVariant == .decaf },
                        set: { isDecaf in
                            let variant: CaffeineVariant = isDecaf ? .decaf : .regular
                            guard variant != selectedCaffeineVariant else { return }
                            selectedCaffeineVariant = variant
                            wateredLog("Add Drink decaf changed to \(isDecaf ? "enabled" : "disabled")")
                        }
                    )) {
                        Label {
                            Text("Decaffeinated")
                        } icon: {
                            Image(systemName: selectedCaffeineVariant == .decaf ? "bolt.slash" : "bolt")
                                .foregroundStyle(.brown)
                        }
                    }
                    .accessibilityIdentifier("addDrinkDecafToggle")
                }
                if let configuration = definition.shotConfiguration {
                    if definition.caffeineOptions.count > 1 {
                        Divider()
                    }
                    let counts = configuration.supportedCounts.sorted()
                    Stepper(value: Binding(
                        get: { counts.firstIndex(of: selectedShotCount) ?? 0 },
                        set: { index in
                            let count = counts[index]
                            guard count != selectedShotCount else { return }
                            wateredLog("Add Drink shots changed from \(selectedShotCount) to \(count)")
                            selectedShotCount = count
                        }
                    ), in: 0...(counts.count - 1)) {
                        Label {
                            Text("Shots: \(selectedShotCount)")
                        } icon: {
                            Image(systemName: "cup.and.saucer")
                                .foregroundStyle(.brown)
                        }
                    }
                    .accessibilityIdentifier("addDrinkShotStepper")
                    .accessibilityValue("\(selectedShotCount)")
                }
            }
            .padding(16)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            .tint(categoryTint(definition.categoryID))
            .padding(.horizontal, 20)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(selectedCategoryID == nil ? "Type" : "Select your drink")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 20)
                    categoryRow
                    if selectedCategoryID != nil {
                        drinkRow
                        preparationSection
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                volumeSection
                    .background(.background)
            }
            .scrollBounceBehavior(.basedOnSize)
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
                if retainedDraft != nil {
                    wateredLog("Add Drink restored unsaved session draft")
                } else {
                    wateredLog("Add Drink opened with a fresh draft")
                }
            }
        }
        .onChange(of: currentDraft) { _, draft in
            retainedDraft = draft
        }
        .presentationDetents([.height(480), .height(600), .height(720), .large], selection: $selectedDetent)
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

