import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct ReviewedMilkEstimateTests {
    private let expected: [(id: String, name: String, ratio: Double, caffeine: Double, serving: Double)] = [
        ("milk", "Milk", 0.9, 0, 250),
        ("oat-milk", "Oat milk", 0.9, 0, 250),
        ("soy-milk", "Soy milk", 0.9, 0, 250),
        ("almond-milk", "Almond milk", 0.95, 0, 250),
        ("coconut-milk", "Coconut milk", 0.95, 0, 250),
        ("rice-milk", "Rice milk", 0.9, 0, 250),
        ("kefir", "Kefir", 0.9, 0, 250),
        ("drinking-yoghurt", "Drinking yoghurt", 0.85, 0, 250),
        ("milkshake", "Milkshake", 0.85, 0, 300),
        ("chocolate-milk", "Chocolate milk", 0.85, 5, 250),
        ("hot-chocolate", "Hot chocolate", 0.85, 5, 250),
        ("ayran", "Ayran", 0.95, 0, 250)
    ]

    @Test func reviewedMembershipDefaultsAndNoPreparation() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        #expect(catalogue.activeDrinks(inCategoryID: "milk-alternatives").map(\.id) == expected.map(\.id))
        for item in expected {
            let drink = try #require(catalogue.drink(withID: item.id))
            #expect(drink.name == item.name)
            #expect(drink.defaultVolume == item.serving)
            #expect(drink.hydrationContributionRule == .ratio(item.ratio))
            #expect(drink.caffeineOptions.map(\.variant) == [.regular])
            #expect(drink.alcohol == .none)
            #expect(drink.shotConfiguration == nil)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func estimatesUsePhysicalVolumeAndRejectUnsupportedPreparations(unit: LiquidUnit) throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        for item in expected {
            for volume in [250.0, 330.0, 500.0] {
                let converted = Measurement(value: volume, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
                let amount = DrinkAmount(value: converted.value, unit: unit)
                let snapshot = try resolver.resolve(drinkID: item.id, amount: amount)
                #expect(abs(try #require(snapshot.hydrationContribution) - volume * item.ratio) < 0.000001)
                #expect(abs(try #require(snapshot.caffeineAmount) - volume / 250 * item.caffeine) < 0.000001)
                #expect(snapshot.shotCount == nil)
                for variant in [CaffeineVariant.decaf, .caffeineFree] {
                    #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                        _ = try resolver.resolve(drinkID: item.id, amount: amount, caffeineVariant: variant)
                    }
                }
            }
        }
    }

    @Test func savedFactsSurviveAndRepeatsUseCurrentMilkRules() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let oldSnapshot = DrinkCatalogueSnapshot(drinkID: "milk", drinkName: "Previously recorded milk",
            caffeineVariant: .regular, shotCount: nil, hydrationContribution: 200, caffeineAmount: nil,
            catalogueVersion: "older-catalogue", calculationVersion: "1", catalogueSchemaVersion: 1)
        let old = DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: oldSnapshot)
        var entries = [old]
        for item in expected {
            entries.append(try AddDrinkDraft(drinkID: item.id, volumeValue: 250, unit: .milliliters)
                .drinkEntry(using: resolver))
        }
        for entry in entries { try DrinkEntryPersistence.save(entry, in: context) }
        let restored = try ModelContext(container).fetch(FetchDescriptor<PersistentDrinkEntry>()).compactMap { $0.drinkEntry() }
        #expect(restored.count == entries.count)
        for entry in entries {
            #expect(restored.first(where: { $0.id == entry.id })?.catalogueSnapshot == entry.catalogueSnapshot)
        }
        let store = WateredStore(entries: [try #require(restored.first(where: { $0.id == old.id }))])
        let recent = try #require(store.recentDrinkOptions(in: catalogue).first)
        let repeated = try recent.drinkEntry(using: resolver)
        #expect(repeated.id != old.id)
        #expect(repeated.catalogueSnapshot.drinkName == "Milk")
        #expect(repeated.catalogueSnapshot.hydrationContribution == 225)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 0)
        #expect(repeated.catalogueSnapshot.catalogueVersion == catalogue.version)
        #expect(store.entries.first?.catalogueSnapshot == oldSnapshot)
    }
}
