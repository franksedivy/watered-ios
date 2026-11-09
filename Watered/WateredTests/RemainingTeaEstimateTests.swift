import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct RemainingTeaEstimateTests {
    private let expected: [(id: String, name: String, ratio: Double, caffeine: Double, serving: Double, free: Bool)] = [
        ("matcha", "Matcha", 0.99, 60, 250, false),
        ("matcha-latte", "Matcha latte", 0.92, 60, 250, false),
        ("bubble-milk-tea", "Bubble milk tea", 0.93, 60, 250, false),
        ("bubble-fruit-tea", "Bubble fruit tea", 0.95, 30, 250, true),
        ("yerba-mate", "Yerba mate", 0.99, 80, 250, false),
        ("iced-tea", "Iced tea", 0.95, 20, 330, true)
    ]

    @Test func membershipDefaultsAndPreparation() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        #expect(catalogue.activeDrinks(inCategoryID: "tea").map(\.id) ==
                ["black-tea", "green-tea", "white-tea", "herbal-tea"] + expected.map(\.id))
        for item in expected {
            let drink = try #require(catalogue.drink(withID: item.id))
            #expect(drink.name == item.name)
            #expect(drink.defaultVolume == item.serving)
            #expect(drink.hydrationContributionRule == .ratio(item.ratio))
            #expect(drink.defaultCaffeineVariant == .regular)
            #expect(drink.caffeineOptions.map(\.variant) == (item.free ? [.regular, .caffeineFree] : [.regular]))
            #expect(drink.shotConfiguration == nil)
            #expect(drink.alcohol == .none)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func estimatesScaleWithoutChangingHydrationForCaffeineFree(unit: LiquidUnit) throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        for item in expected {
            for volume in [250.0, 330.0, 500.0] {
                let converted = Measurement(value: volume, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
                let amount = DrinkAmount(value: converted.value, unit: unit)
                for variant in item.free ? [CaffeineVariant.regular, .caffeineFree] : [.regular] {
                    let snapshot = try resolver.resolve(drinkID: item.id, amount: amount, caffeineVariant: variant)
                    #expect(abs(try #require(snapshot.hydrationContribution) - volume * item.ratio) < 0.000001)
                    let caffeine = variant == .caffeineFree ? 0 : volume / 250 * item.caffeine
                    #expect(abs(try #require(snapshot.caffeineAmount) - caffeine) < 0.000001)
                    #expect(snapshot.caffeineVariant == variant)
                    #expect(snapshot.shotCount == nil)
                }
                #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                    _ = try resolver.resolve(drinkID: item.id, amount: amount, caffeineVariant: .decaf)
                }
                if !item.free {
                    #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                        _ = try resolver.resolve(drinkID: item.id, amount: amount, caffeineVariant: .caffeineFree)
                    }
                }
            }
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func icedTeaServingRetainsExactVolumeAndRespectsDrafts(unit: LiquidUnit) {
        var fresh = AddDrinkVolumeSelection(value: AddDrinkVolumeSelection.defaultValue(for: unit), unit: unit)
        fresh.applyServingDefault(250)
        fresh.applyServingDefault(330)
        #expect(fresh.amount.volume.converted(to: .milliliters).value == 330)
        #expect(fresh.options(in: unit).contains(fresh.displayValue(in: unit)))
        fresh.select(500, displayedAs: .milliliters)
        fresh.applyServingDefault(330)
        #expect(fresh.amount.volume.converted(to: .milliliters).value == 500)
        var restored = AddDrinkVolumeSelection(value: 250, unit: .milliliters, canApplyServingDefault: false)
        restored.applyServingDefault(330)
        #expect(restored.value == 250)
    }

    @Test func caffeineFreePersistsAndRepeatsWithoutRewritingOldHistory() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var entries: [DrinkEntry] = []
        for variant in [CaffeineVariant.regular, .decaf] {
            let old = DrinkCatalogueSnapshot(drinkID: "black-tea", drinkName: "Previously logged tea",
                caffeineVariant: variant, shotCount: nil, hydrationContribution: 230, caffeineAmount: nil,
                catalogueVersion: "older-catalogue", calculationVersion: "1", catalogueSchemaVersion: 1)
            entries.append(DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
                date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: old))
        }
        for id in ["bubble-fruit-tea", "iced-tea"] {
            entries.append(try AddDrinkDraft(drinkID: id, volumeValue: 330, unit: .milliliters,
                caffeineVariant: .caffeineFree).drinkEntry(using: resolver))
        }
        for entry in entries { try DrinkEntryPersistence.save(entry, in: context) }
        let records = try ModelContext(container).fetch(FetchDescriptor<PersistentDrinkEntry>())
        let restored = records.compactMap { $0.drinkEntry() }
        #expect(restored.count == entries.count)
        for entry in entries {
            #expect(restored.first(where: { $0.id == entry.id })?.catalogueSnapshot == entry.catalogueSnapshot)
            let encoded = try JSONEncoder().encode(entry.catalogueSnapshot.caffeineVariant)
            #expect(try JSONDecoder().decode(CaffeineVariant.self, from: encoded) == entry.catalogueSnapshot.caffeineVariant)
        }
        let store = WateredStore(entries: restored)
        let recents = store.recentDrinkOptions(in: catalogue)
        for recent in recents where recent.caffeineVariant == .caffeineFree {
            #expect(recent.label(displayedAs: .milliliters).contains("Caffeine-free"))
            let repeated = try recent.drinkEntry(using: resolver)
            #expect(!entries.contains(where: { $0.id == repeated.id }))
            #expect(repeated.catalogueSnapshot.caffeineVariant == .caffeineFree)
            #expect(repeated.catalogueSnapshot.caffeineAmount == 0)
            #expect(abs(try #require(repeated.catalogueSnapshot.hydrationContribution) - 313.5) < 0.000001)
            #expect(repeated.catalogueSnapshot.catalogueVersion == "development-11")
        }
        #expect(recents.filter { $0.caffeineVariant == .caffeineFree }.count == 2)
        #expect(store.entries.filter { $0.drinkID == "black-tea" }.allSatisfy { $0.catalogueSnapshot.caffeineAmount == nil })
    }

    @Test func rejectsNonzeroOrUnknownCaffeineFreeRules() throws {
        let bundled = try DrinkCatalogueLoader().load()
        for rule in [CaffeineRule.unknown, .perVolume(concentration: 1), .perShot(amount: 0)] {
            let drink = DrinkDefinition(id: "test-tea", name: "Test", categoryID: "tea", sortOrder: 1,
                isRetired: false, caffeineOptions: [CaffeineOption(variant: .caffeineFree, rule: rule)],
                defaultCaffeineVariant: .caffeineFree)
            let catalogue = DrinkCatalogue(schemaVersion: 3, version: "test", categories: bundled.categories, drinks: [drink])
            #expect(throws: DrinkCatalogue.ValidationError.invalidCaffeineValue(drinkID: "test-tea", variant: .caffeineFree)) {
                try catalogue.validate()
            }
        }
    }
}
