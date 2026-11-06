import Foundation

/// Retains the exact selected amount while preparing wheel values in the applied display unit.
nonisolated struct AddDrinkVolumeSelection: Equatable {
    private(set) var value: Double
    private(set) var unit: LiquidUnit

    var amount: DrinkAmount { DrinkAmount(value: value, unit: unit) }

    func displayValue(in displayUnit: LiquidUnit) -> Double {
        if unit == displayUnit { return value }
        return amount.volume.converted(to: displayUnit.foundationUnit).value
    }

    /// Includes a converted, non-preset selection without snapping or rounding its value.
    func options(in displayUnit: LiquidUnit) -> [Double] {
        let presets: [Double]
        switch displayUnit {
        case .milliliters: presets = [150, 200, 250, 300, 330, 400, 500, 600, 750, 1000]
        case .usFluidOunces: presets = [6, 8, 10, 12, 16, 20, 24, 32]
        case .imperialFluidOunces: presets = [5, 8, 10, 12, 16, 20, 24, 32]
        }
        return Array(Set(presets + [displayValue(in: displayUnit)])).sorted()
    }

    func label(for displayedValue: Double, in displayUnit: LiquidUnit, locale: Locale = .current) -> String {
        VolumeFormatter(locale: locale).string(
            from: Measurement(value: displayedValue, unit: displayUnit.foundationUnit),
            displayedAs: displayUnit
        )
    }

    /// Only a deliberate change replaces the captured amount; display round-trips never do.
    mutating func select(_ displayedValue: Double, displayedAs displayUnit: LiquidUnit) {
        guard displayedValue != displayValue(in: displayUnit) else { return }
        value = displayedValue
        unit = displayUnit
    }

    static func defaultValue(for unit: LiquidUnit) -> Double {
        switch unit {
        case .milliliters: return 330
        case .usFluidOunces: return 12
        case .imperialFluidOunces: return 8
        }
    }
}
