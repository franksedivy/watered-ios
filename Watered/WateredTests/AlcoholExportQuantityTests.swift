import Foundation
import Testing
@testable import Watered

struct AlcoholExportQuantityTests {
    @Test(arguments: LiquidUnit.allCases)
    func approvedExamplesKeepFractionalCountsInEveryUnit(unit: LiquidUnit) throws {
        // Expected grams are worked examples, independent of the conversion implementation.
        for (ml, abv, grams) in [(330.0, 0.05, 13.0185), (175, 0.13, 17.94975),
                                  (25, 0.40, 7.89), (200, 0.10, 15.78)] {
            let converted = Measurement(value: ml, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
            let result = AlcoholExportQuantity.resolve(entry(amount: .init(value: converted.value, unit: unit), abv: abv))
            guard case .standardDrinks(let count) = result else {
                Issue.record("Expected a fractional standard-drink count")
                continue
            }
            #expect(abs(count - grams / 14) < 0.000000001)
        }
    }

    @Test func zeroUnknownAndUpperBoundNeverBecomePositiveSamples() {
        #expect(AlcoholExportQuantity.resolve(entry(abv: 0)) == .knownZero)
        #expect(AlcoholExportQuantity.resolve(entry(abv: 0, nonAlcoholic: true)) == .knownZero)
        #expect(AlcoholExportQuantity.resolve(entry(abv: nil)) == .unknown)
        #expect(AlcoholExportQuantity.resolve(entry(abv: nil, bound: 0.005, nonAlcoholic: true)) == .unknown)
        #expect(AlcoholExportQuantity.resolve(entry(abv: 0.005, bound: 0.005, nonAlcoholic: true)) == .invalid)
    }

    @Test func invalidFactsAreRejected() {
        for volume in [0.0, -1, .nan, .infinity] {
            #expect(AlcoholExportQuantity.resolve(entry(amount: .init(value: volume, unit: .milliliters), abv: 0.05)) == .invalid)
        }
        for abv in [-0.01, 1.01, .nan, .infinity] {
            #expect(AlcoholExportQuantity.resolve(entry(abv: abv)) == .invalid)
            #expect(AlcoholExportQuantity.resolve(entry(abv: nil, bound: abv)) == .invalid)
        }
        #expect(AlcoholExportQuantity.resolve(entry(abv: 0.05, nonAlcoholic: true)) == .invalid)
    }

    @Test func savedFactsRemainIndependentOfRecipeNamesAndOtherEstimates() {
        let original = entry(abv: 0.05)
        let renamed = entry(abv: 0.05, name: "Retired recipe", hydration: -100, water: nil, caffeine: 80)
        #expect(AlcoholExportQuantity.resolve(original) == AlcoholExportQuantity.resolve(renamed))
        guard case .standardDrinks(let single) = AlcoholExportQuantity.resolve(original),
              case .standardDrinks(let double) = AlcoholExportQuantity.resolve(entry(abv: 0.10)) else {
            Issue.record("Expected counts from saved strengths")
            return
        }
        #expect(abs(double - single * 2) < 0.000000001)
        #expect(AlcoholExportQuantity.policyVersion == "alcohol-14g-v1")
    }

    private func entry(amount: DrinkAmount = .init(value: 330, unit: .milliliters),
                       abv: Double?, bound: Double? = nil, nonAlcoholic: Bool? = nil,
                       name: String = "Saved drink", hydration: Double? = 0,
                       water: Double? = 306.9, caffeine: Double? = nil) -> DrinkEntry {
        let snapshot = DrinkCatalogueSnapshot(drinkID: "retired-test", drinkName: name,
            caffeineVariant: .regular, shotCount: nil, hydrationContribution: hydration,
            caffeineAmount: caffeine, catalogueVersion: "historical", calculationVersion: "5",
            catalogueSchemaVersion: 6, waterAmount: water, isNonAlcoholic: nonAlcoholic,
            alcoholABV: abv, alcoholABVUpperBound: bound)
        return DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
    }
}
