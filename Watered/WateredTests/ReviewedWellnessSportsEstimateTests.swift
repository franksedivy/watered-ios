import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct ReviewedWellnessSportsEstimateTests {
    private let expected: [(id: String, name: String, ratio: Double, caffeine: Double, serving: Double)] = [
        ("kombucha", "Kombucha", 0.95, 10, 250),
        ("vitamin-drink", "Vitamin drink", 0.95, 0, 500),
        ("cbd-drink", "CBD drink", 0.95, 0, 250),
        ("energy-drink", "Energy drink", 0.9, 80, 250),
        ("sports-drink", "Sports drink", 0.95, 0, 500),
        ("electrolyte-drink", "Electrolyte drink", 0.95, 0, 500),
        ("protein-shake", "Protein shake", 0.9, 0, 300)
    ]

    @Test func reviewedMembershipDefaultsAndNoPreparation() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        #expect(catalogue.activeDrinks(inCategoryID: "wellness").map(\.id) == Array(expected.prefix(3)).map(\.id))
        #expect(catalogue.activeDrinks(inCategoryID: "sports-energy").map(\.id) == Array(expected.suffix(4)).map(\.id))
        for item in expected {
            let drink = try #require(catalogue.drink(withID: item.id))
            #expect(drink.name == item.name)
            #expect(drink.defaultVolume == item.serving)
            #expect(drink.hydrationContributionRule == .ratio(item.ratio))
            #expect(drink.caffeineOptions.map(\.variant) == [.regular])
            #expect(drink.alcohol == (item.id == "kombucha" ? .unknown : .none))
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

    @Test func savedFactsSurviveAndRepeatsUseCurrentWellnessSportsRules() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let oldSnapshot = DrinkCatalogueSnapshot(drinkID: "kombucha", drinkName: "Previously recorded kombucha",
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
        #expect(repeated.catalogueSnapshot.drinkName == "Kombucha")
        #expect(repeated.catalogueSnapshot.hydrationContribution == 237.5)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 10)
        #expect(repeated.catalogueSnapshot.catalogueVersion == catalogue.version)
        #expect(store.entries.first?.catalogueSnapshot == oldSnapshot)
    }
}
