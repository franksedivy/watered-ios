import Foundation
import Testing
@testable import Watered

@MainActor
struct VolumeFormatterTests {
    // Given a volume and milliliter display unit, when it is formatted, then the
    // string shows the whole-number milliliter value.
    @Test func volumeFormatterFormatsWholeMilliliters() {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let volume = Measurement(value: 1000, unit: UnitVolume.milliliters)

        #expect(formatter.wholeNumberString(from: volume, displayedAs: .milliliters) == "1000 ml")
    }

    // Given a milliliter volume and US fluid ounce display unit, when it is
    // formatted, then the string shows the rounded US fluid ounce value.
    @Test func volumeFormatterFormatsWholeUSFluidOunces() {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let volume = Measurement(value: 1000, unit: UnitVolume.milliliters)

        #expect(formatter.wholeNumberString(from: volume, displayedAs: .usFluidOunces) == "34 US fl oz")
    }

    // Given a milliliter volume and imperial fluid ounce display unit, when it is
    // formatted, then the string shows the rounded imperial fluid ounce value.
    @Test func volumeFormatterFormatsWholeImperialFluidOunces() {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let volume = Measurement(value: 1000, unit: UnitVolume.milliliters)

        #expect(formatter.wholeNumberString(from: volume, displayedAs: .imperialFluidOunces) == "35 fl oz")
    }

    // GIVEN an amount logged in imperial ounces, when its display unit changes,
    // THEN the number and unit are converted together without changing the source measurement.
    @Test(arguments: LiquidUnit.allCases)
    func preciseFormattingConvertsOriginalImperialAmount(unit: LiquidUnit) {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let original = Measurement(value: 8, unit: UnitVolume.imperialFluidOunces)
        let expected: String
        switch unit {
        case .milliliters: expected = "227.305 ml"
        case .usFluidOunces: expected = "7.686 US fl oz"
        case .imperialFluidOunces: expected = "8 fl oz"
        }

        #expect(formatter.string(from: original, displayedAs: unit) == expected)
        #expect(original.value == 8)
        #expect(original.unit == .imperialFluidOunces)
    }

    // GIVEN a saved contribution in base units, when it is formatted for inspection,
    // THEN it has the same equivalent value as the matching originally logged volume.
    @Test(arguments: LiquidUnit.allCases)
    func savedContributionUsesSameDisplayUnitAsLoggedAmount(unit: LiquidUnit) {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let original = Measurement(value: 8, unit: UnitVolume.imperialFluidOunces)
        let savedContribution = VolumeCalculation.baseValue(from: original)
        let restoredContribution = VolumeCalculation.measurement(fromBaseValue: savedContribution)

        #expect(
            formatter.string(from: restoredContribution, displayedAs: unit)
                == formatter.string(from: original, displayedAs: unit)
        )
    }

    // GIVEN small positive and negative contributions, when fluid ounces are displayed,
    // THEN fractional precision preserves their sign and avoids whole-number zero rounding.
    @Test func preciseFormattingPreservesSmallContributions() {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let positive = Measurement(value: 1, unit: UnitVolume.milliliters)
        let negative = Measurement(value: -1, unit: UnitVolume.milliliters)

        #expect(formatter.string(from: positive, displayedAs: .usFluidOunces) == "0.034 US fl oz")
        #expect(formatter.string(from: negative, displayedAs: .usFluidOunces) == "-0.034 US fl oz")
    }

    // GIVEN a known zero contribution, when any supported display unit is selected,
    // THEN zero remains a known numeric value rather than becoming unknown.
    @Test(arguments: LiquidUnit.allCases)
    func preciseFormattingPreservesKnownZero(unit: LiquidUnit) {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let zero = Measurement(value: 0, unit: UnitVolume.milliliters)

        #expect(
            formatter.string(from: zero, displayedAs: unit)
                == formatter.wholeNumberString(from: zero, displayedAs: unit)
        )
    }
}
