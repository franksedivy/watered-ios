import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct ReviewedSoftDrinkEstimateTests {
    private let expected: [(id: String, name: String, ratio: Double, serving: Double)] = [
        ("cola", "Cola", 0.90, 330),
        ("lemonade", "Lemonade", 0.90, 330),
        ("tonic-water", "Tonic water", 0.90, 200),
        ("fruit-soda", "Fruit soda", 0.90, 330),
        ("ginger-beer", "Ginger beer", 0.90, 330),
        ("squash", "Squash", 0.95, 250)
    ]

    @Test func reviewedMembershipDefaultsAndSupportedPreparation() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        #expect(catalogue.activeDrinks(inCategoryID: "soft-drinks").map(\.id) == expected.map(\.id))
        for item in expected {
            let drink = try #require(catalogue.drink(withID: item.id))
            #expect(drink.name == item.name)
            #expect(drink.defaultVolume == item.serving)
            #expect(drink.hydrationContributionRule == .ratio(item.ratio))
            #expect(drink.caffeineOptions.map(\.variant) == (item.id == "cola" ? [.regular, .caffeineFree] : [.regular]))
            #expect(drink.defaultCaffeineVariant == .regular)
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
                #expect(abs(try #require(snapshot.caffeineAmount) - (item.id == "cola" ? volume * 0.1 : 0)) < 0.000001)
                if item.id == "cola" {
                    let free = try resolver.resolve(drinkID: item.id, amount: amount, caffeineVariant: .caffeineFree)
                    #expect(free.caffeineAmount == 0)
                    #expect(free.hydrationContribution == snapshot.hydrationContribution)
                }
                #expect(snapshot.shotCount == nil)
                for variant in item.id == "cola" ? [CaffeineVariant.decaf] : [.decaf, .caffeineFree] {
                    #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                        _ = try resolver.resolve(drinkID: item.id, amount: amount, caffeineVariant: variant)
                    }
                }
            }
        }
    }

    @Test func savedFactsSurviveAndRepeatsUseCurrentSoftDrinkRules() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let oldSnapshot = DrinkCatalogueSnapshot(drinkID: "cola", drinkName: "Previously recorded cola",
            caffeineVariant: .regular, shotCount: nil, hydrationContribution: 200, caffeineAmount: nil,
            catalogueVersion: "older-catalogue", calculationVersion: "1", catalogueSchemaVersion: 1)
        let old = DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: oldSnapshot)
        var entries = [old]
        for item in expected {
            entries.append(try AddDrinkDraft(drinkID: item.id, volumeValue: 250, unit: .milliliters)
                .drinkEntry(using: resolver))
        }
        entries.append(try AddDrinkDraft(drinkID: "cola", volumeValue: 330, unit: .milliliters, caffeineVariant: .caffeineFree).drinkEntry(using: resolver))
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
        #expect(repeated.catalogueSnapshot.drinkName == "Cola")
        #expect(repeated.catalogueSnapshot.hydrationContribution == 225)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 25)
        #expect(repeated.catalogueSnapshot.catalogueVersion == catalogue.version)
        #expect(store.entries.first?.catalogueSnapshot == oldSnapshot)
    }
}
