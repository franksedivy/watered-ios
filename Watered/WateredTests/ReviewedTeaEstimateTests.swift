import Foundation
import Testing
@testable import Watered

@MainActor
struct ReviewedTeaEstimateTests {
    @Test func bundledTeaMembershipAndPreparation() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let teas = Array(catalogue.activeDrinks(inCategoryID: "tea").prefix(4))
        #expect(teas.map(\.id) == ["black-tea", "green-tea", "white-tea", "herbal-tea"])
        #expect(AddDrinkCategoryDefaults.drink(in: "tea", from: teas)?.id == "black-tea")
        for tea in teas {
            #expect(tea.defaultVolume == 250)
            #expect(tea.hydrationContributionRule == .ratio(0.99))
            #expect(tea.alcohol == .none)
            #expect(tea.shotConfiguration == nil)
            #expect(tea.defaultCaffeineVariant == .regular)
            #expect(tea.caffeineOptions.map(\.variant) == (tea.id == "herbal-tea" ? [.regular] : [.regular, .decaf]))
        }
        #expect(teas.last?.caffeine == CaffeineContent.none)
    }

    @Test(arguments: LiquidUnit.allCases)
    func estimatesScaleWithPhysicalVolume(unit: LiquidUnit) throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        for volume in [250.0, 500.0] {
            let converted = Measurement(value: volume, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
            let amount = DrinkAmount(value: converted.value, unit: unit)
            for (id, regular) in [("black-tea", 50.0), ("green-tea", 30.0), ("white-tea", 30.0), ("herbal-tea", 0.0)] {
                for variant in id == "herbal-tea" ? [CaffeineVariant.regular] : [CaffeineVariant.regular, .decaf] {
                    let snapshot = try resolver.resolve(drinkID: id, amount: amount, caffeineVariant: variant)
                    #expect(abs(try #require(snapshot.hydrationContribution) - volume * 0.99) < 0.000001)
                    #expect(abs(try #require(snapshot.caffeineAmount) - volume / 250 * (variant == .decaf ? 5 : regular)) < 0.000001)
                    #expect(snapshot.shotCount == nil)
                    #expect(snapshot.catalogueVersion == "development-15")
                }
            }
        }
        #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
            _ = try resolver.resolve(drinkID: "herbal-tea", amount: DrinkAmount(value: 250, unit: .milliliters), caffeineVariant: .decaf)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func servingDefaultPreservesExactAmountAndUserChoices(unit: LiquidUnit) {
        var fresh = AddDrinkVolumeSelection(value: AddDrinkVolumeSelection.defaultValue(for: unit), unit: unit)
        fresh.applyServingDefault(250)
        #expect(fresh.amount.volume.converted(to: .milliliters).value == 250)
        #expect(fresh.options(in: unit).contains(fresh.displayValue(in: unit)))
        fresh.select(500, displayedAs: .milliliters)
        fresh.applyServingDefault(250)
        #expect(fresh.amount.volume.converted(to: .milliliters).value == 500)
        var restored = AddDrinkVolumeSelection(value: 12, unit: unit, canApplyServingDefault: false)
        restored.applyServingDefault(250)
        #expect(restored.value == 12)
        #expect(restored.unit == unit)
    }

    @Test func historyRetainsCapturedTeaFactsWhileRepeatUsesReviewedRules() throws {
        let old = DrinkCatalogueSnapshot(
            drinkID: "black-tea", drinkName: "Previously logged tea", caffeineVariant: .decaf,
            shotCount: nil, hydrationContribution: 230, caffeineAmount: nil,
            catalogueVersion: "older-catalogue", calculationVersion: "1", catalogueSchemaVersion: 1
        )
        let entry = DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
                               date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: old)
        let record = PersistentDrinkEntry(drinkEntry: entry)
        let restored = try #require(record.drinkEntry())
        let catalogue = try DrinkCatalogueLoader().load()
        let store = WateredStore(entries: [restored])
        let recent = try #require(store.recentDrinkOptions(in: catalogue).first)
        let repeated = try recent.drinkEntry(using: DrinkCatalogueSnapshotResolver(catalogue: catalogue))
        #expect(repeated.id != restored.id)
        #expect(repeated.catalogueSnapshot.caffeineVariant == .decaf)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 5)
        #expect(repeated.catalogueSnapshot.hydrationContribution == 247.5)
        #expect(repeated.catalogueSnapshot.catalogueVersion == "development-15")
        #expect(store.entries.first?.catalogueSnapshot == old)
        #expect(record.drinkEntry()?.catalogueSnapshot == old)
    }
}
