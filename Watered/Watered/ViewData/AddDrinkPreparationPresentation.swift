import Foundation

/// Keeps category preparation rows stable while deriving editable choices from catalogue facts.
/// Disabled placeholders are presentation only and never supply a preparation for submission.
nonisolated struct AddDrinkPreparationPresentation {
    struct CaffeineRow {
        let alternative: CaffeineVariant
        let isEnabled: Bool

        var title: String { alternative == .decaf ? "Decaffeinated" : "Caffeine-free" }
        var accessibilityIdentifier: String {
            alternative == .decaf ? "addDrinkDecafToggle" : "addDrinkCaffeineFreeToggle"
        }
    }

    struct AlcoholRows {
        let configuration: AlcoholConfiguration

        var isNonAlcoholicEnabled: Bool { configuration.nonAlcoholic != nil }

        /// The disabled indicator marks the recipe's upper bound, never an exact non-alcoholic ABV.
        func strength(isNonAlcoholic: Bool, selectedABV: Double?) -> AlcoholStrength {
            if isNonAlcoholic, let preparation = configuration.nonAlcoholic {
                return AlcoholStrength(
                    values: [0, preparation.maximumABV], selectedIndex: 1, isUpperBound: true
                )
            }
            let values = configuration.supportedABVs
            let value = selectedABV ?? configuration.defaultABV
            return AlcoholStrength(
                values: values, selectedIndex: values.firstIndex(of: value) ?? 0, isUpperBound: false
            )
        }
    }

    struct AlcoholStrength {
        let values: [Double]
        let selectedIndex: Int
        let isUpperBound: Bool

        var valueLabel: String { Self.label(values[selectedIndex]) }
        var title: String {
            isUpperBound ? "Up to \(valueLabel) ABV · exact amount unknown" : "Alcohol: \(valueLabel) ABV"
        }
        var accessibilityValue: String {
            isUpperBound ? "Up to \(valueLabel) ABV; exact amount unknown" : valueLabel
        }
        static func label(_ value: Double) -> String {
            (value * 100).formatted(.number.precision(.fractionLength(0...1))) + "%"
        }
    }

    let caffeineRow: CaffeineRow?
    let showsShots: Bool
    let shotConfiguration: ShotConfiguration?
    let alcoholRows: AlcoholRows?

    var hasRows: Bool { caffeineRow != nil || showsShots || alcoholRows != nil }

    init(definition: DrinkDefinition) {
        let alternative = definition.caffeineOptions.first {
            $0.variant == .decaf || $0.variant == .caffeineFree
        }?.variant
        let supportsAlternative = definition.caffeineOptions.contains { $0.variant == .regular }
            && alternative != nil
        let placeholder: CaffeineVariant?
        switch definition.categoryID {
        case "coffee", "tea": placeholder = .decaf
        case "soft-drinks": placeholder = .caffeineFree
        default: placeholder = nil
        }
        if supportsAlternative, let alternative {
            caffeineRow = CaffeineRow(alternative: alternative, isEnabled: true)
        } else if let placeholder {
            caffeineRow = CaffeineRow(alternative: placeholder, isEnabled: false)
        } else {
            caffeineRow = nil
        }
        shotConfiguration = definition.shotConfiguration
        showsShots = definition.categoryID == "coffee" || shotConfiguration != nil
        alcoholRows = definition.alcohol.configuration.map { AlcoholRows(configuration: $0) }
    }

    /// Fresh and restored forms reserve the same space for persistent category rows.
    static func sheetHeight(categoryID: String?, definition: DrinkDefinition?) -> CGFloat {
        guard let categoryID else { return 440 }
        switch categoryID {
        case "alcohol": return 780
        case "coffee": return 720
        case "tea", "soft-drinks": return 660
        default:
            return definition.map { Self(definition: $0).hasRows } == true ? 720 : 600
        }
    }
}
