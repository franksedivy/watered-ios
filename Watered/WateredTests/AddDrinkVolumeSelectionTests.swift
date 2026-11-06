import Foundation
import Testing
@testable import Watered

@MainActor
struct AddDrinkVolumeSelectionTests {
    @Test(arguments: LiquidUnit.allCases, LiquidUnit.allCases)
    func displayAndSavePreserveExactAmount(source: LiquidUnit, display: LiquidUnit) throws {
        var selection = AddDrinkVolumeSelection(value: 500.123456789, unit: source)
        let original = selection
        let expected = original.amount.volume.converted(to: display.foundationUnit).value
        #expect(abs(selection.displayValue(in: display) - expected) < 0.000000001)
        #expect(selection.options(in: display).contains(selection.displayValue(in: display)))
        let locale = Locale(identifier: "en_GB")
        #expect(selection.label(for: selection.displayValue(in: display), in: display, locale: locale)
            == VolumeFormatter(locale: locale).string(from: original.amount.volume, displayedAs: display))

        // Wheel updates for its existing selection and repeated reopening must not recapture conversion.
        for _ in 0..<20 {
            for unit in [display, source, LiquidUnit.milliliters] {
                selection.select(selection.displayValue(in: unit), displayedAs: unit)
            }
        }
        #expect(selection == original)
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        let entry = try AddDrinkDraft(
            drinkID: "latte", volumeValue: selection.value, unit: selection.unit,
            caffeineVariant: .decaf, shotCount: 3
        ).drinkEntry(using: resolver)
        #expect(entry.amount.value == original.value)
        #expect(entry.amount.unit == source)
        #expect(entry.catalogueSnapshot.caffeineVariant == .decaf)
        #expect(entry.catalogueSnapshot.shotCount == 3)
    }

    @Test(arguments: LiquidUnit.allCases)
    func freshDefaultsAndDeliberatePresetSelection(unit: LiquidUnit) {
        var selection = AddDrinkVolumeSelection(
            value: AddDrinkVolumeSelection.defaultValue(for: unit), unit: unit
        )
        #expect(selection.options(in: unit).contains(selection.value))
        selection.select(20, displayedAs: unit)
        #expect(selection.value == 20)
        #expect(selection.unit == unit)
    }

    @Test func convertedNonPresetIsSelectableWithoutRoundingAndNewPresetReplacesIt() {
        var selection = AddDrinkVolumeSelection(value: 500, unit: .milliliters)
        let converted = selection.displayValue(in: .usFluidOunces)
        #expect(converted > 16 && converted < 20)
        #expect(selection.options(in: .usFluidOunces).contains(converted))
        #expect(selection.label(for: converted, in: .usFluidOunces, locale: Locale(identifier: "en_GB"))
            == "16.907 US fl oz")
        selection.select(converted, displayedAs: .usFluidOunces)
        #expect(selection.value == 500)
        #expect(selection.unit == .milliliters)
        selection.select(16, displayedAs: .usFluidOunces)
        #expect(selection.value == 16)
        #expect(selection.unit == .usFluidOunces)
        #expect(abs(selection.displayValue(in: .milliliters) - 473.176) < 0.001)
    }
}
