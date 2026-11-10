import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct ReviewedOtherEstimateTests {
    private let expected: [(id: String, name: String, ratio: Double)] = [
        ("broth", "Broth", 0.95),
        ("miso", "Miso soup", 0.95)
    ]

    @Test func reviewedMembershipDefaultsAndNoPreparation() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        #expect(catalogue.activeDrinks(inCategoryID: "other").map(\.id) == expected.map(\.id))
        for item in expected {
            let drink = try #require(catalogue.drink(withID: item.id))
            #expect(drink.name == item.name)
            #expect(drink.defaultVolume == 250)
            #expect(drink.hydrationContributionRule == .ratio(item.ratio))
            #expect(drink.caffeine == .none)
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
                #expect(snapshot.caffeineAmount == 0)
                #expect(snapshot.shotCount == nil)
                for variant in [CaffeineVariant.decaf, .caffeineFree] {
                    #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                        _ = try resolver.resolve(drinkID: item.id, amount: amount, caffeineVariant: variant)
                    }
                }
            }
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func servingDefaultsRetainManualAndRestoredVolumes(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        for item in expected {
            let definition = try #require(catalogue.drink(withID: item.id))
            var fresh = AddDrinkVolumeSelection(value: AddDrinkVolumeSelection.defaultValue(for: unit), unit: unit)
            fresh.applyServingDefault(definition.defaultVolume)
            #expect(fresh.amount.volume.converted(to: .milliliters).value == 250)
            #expect(fresh.options(in: unit).contains(fresh.displayValue(in: unit)))
            fresh.select(500, displayedAs: .milliliters)
            fresh.applyServingDefault(definition.defaultVolume)
            #expect(fresh.amount.volume.converted(to: .milliliters).value == 500)
            var restored = AddDrinkVolumeSelection(value: 12, unit: unit, canApplyServingDefault: false)
            let original = restored
            restored.applyServingDefault(definition.defaultVolume)
            #expect(restored == original)
        }
    }

    @Test func savedFactsSurviveAndRepeatsUseCurrentOtherRules() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let oldSnapshot = DrinkCatalogueSnapshot(drinkID: "broth", drinkName: "Previously recorded broth",
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
        #expect(repeated.catalogueSnapshot.drinkName == "Broth")
        #expect(repeated.catalogueSnapshot.hydrationContribution == 237.5)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 0)
        #expect(repeated.catalogueSnapshot.catalogueVersion == catalogue.version)
        #expect(store.entries.first?.catalogueSnapshot == oldSnapshot)
    }
}
