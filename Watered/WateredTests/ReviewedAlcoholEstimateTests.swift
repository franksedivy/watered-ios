import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct ReviewedAlcoholEstimateTests {
    private let expected: [(id: String, serving: Double, abv: Double, steps: [Double], nonAlcoholic: Bool)] = [
        ("beer", 330, 0.05, [0.04, 0.045, 0.05, 0.055, 0.06], true),
        ("cider", 330, 0.045, [0.04, 0.045, 0.05, 0.055, 0.06], true),
        ("wine", 175, 0.13, [0.11, 0.12, 0.13, 0.14, 0.15], true),
        ("sparkling-wine", 125, 0.12, [0.10, 0.11, 0.12, 0.13, 0.14], true),
        ("fortified-wine", 50, 0.18, [0.14, 0.16, 0.18, 0.20, 0.22], false),
        ("spirits", 25, 0.40, [0.30, 0.40, 0.50, 0.60], false),
        ("liqueur", 25, 0.20, [0.15, 0.20, 0.25, 0.30, 0.35, 0.40], false),
        ("cocktail", 200, 0.10, [0.05, 0.10, 0.15, 0.20, 0.25], true)
    ]

    @Test func membershipDefaultsAndContentRoundTrip() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        #expect(catalogue.activeDrinks(inCategoryID: "alcohol").map(\.id) == expected.map(\.id))
        let restored = try JSONDecoder().decode(DrinkCatalogue.self, from: JSONEncoder().encode(catalogue))
        try restored.validate()
        #expect(restored == catalogue)
        for item in expected {
            let drink = try #require(catalogue.drink(withID: item.id))
            let configuration = try #require(drink.alcohol.configuration)
            #expect(drink.defaultVolume == item.serving)
            #expect(configuration.defaultABV == item.abv)
            #expect(configuration.supportedABVs == item.steps)
            #expect((configuration.nonAlcoholic != nil) == item.nonAlcoholic)
            #expect(drink.shotConfiguration == nil)
            #expect(drink.caffeine == (["cocktail", "liqueur"].contains(item.id) ? .unknown : .none))
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func allStepsPreserveFluidVolumeAndResolveIndependentEstimates(unit: LiquidUnit) throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        for item in expected {
            let volume = Measurement(value: item.serving, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
            let amount = DrinkAmount(value: volume.value, unit: unit)
            let defaultSnapshot = try resolver.resolve(drinkID: item.id, amount: amount)
            #expect(defaultSnapshot.alcoholABV == item.abv)
            for step in item.steps {
                let entry = try AddDrinkDraft(drinkID: item.id, volumeValue: volume.value, unit: unit,
                    alcoholABV: step).drinkEntry(using: resolver)
                #expect(abs(VolumeCalculation.baseValue(from: entry.amount.volume) - item.serving) < 0.000001)
                #expect(entry.catalogueSnapshot.hydrationContribution == 0)
                #expect(entry.catalogueSnapshot.alcoholABV == step)
                #expect(entry.catalogueSnapshot.isNonAlcoholic == false)
                #expect(entry.catalogueSnapshot.alcoholABVUpperBound == nil)
                #expect(entry.catalogueSnapshot.caffeineAmount == (["cocktail", "liqueur"].contains(item.id) ? nil : 0))
            }
            if item.nonAlcoholic {
                let snapshot = try resolver.resolve(drinkID: item.id, amount: amount, isNonAlcoholic: true)
                #expect(abs(try #require(snapshot.hydrationContribution) - item.serving * 0.95) < 0.000001)
                #expect(snapshot.isNonAlcoholic == true)
                #expect(snapshot.alcoholABV == nil)
                #expect(snapshot.alcoholABVUpperBound == 0.005)
                #expect(snapshot.caffeineAmount == (item.id == "cocktail" ? nil : 0))
            }
        }
    }

    @Test func fluidIntakeAndGoalProgressRemainSeparate() throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        let water = try AddDrinkDraft(drinkID: "still-water", volumeValue: 500, unit: .milliliters).drinkEntry(using: resolver)
        let beer = try AddDrinkDraft(drinkID: "beer", volumeValue: 330, unit: .milliliters).drinkEntry(using: resolver)
        let mocktail = try AddDrinkDraft(drinkID: "cocktail", volumeValue: 200, unit: .milliliters,
            isNonAlcoholic: true).drinkEntry(using: resolver)
        let tracker = HydrationTracker(entries: [water, beer, mocktail],
            dailyGoal: HydrationGoal(amount: DrinkAmount(value: 2100, unit: .milliliters)))
        #expect(tracker.totalVolume.value == 1030)
        #expect(tracker.totalHydrationVolume?.value == 690)
        #expect(tracker.remainingHydrationVolume?.value == 1410)
        #expect(tracker.dailyGoal.volume.value == 2100)
    }

    @Test func repeatsRecalculateNonAlcoholicCreditAndExcludeRemovedChoices() throws {
        let bundled = try DrinkCatalogueLoader().load()
        let originalResolver = try DrinkCatalogueSnapshotResolver(catalogue: bundled)
        let original = try AddDrinkDraft(drinkID: "beer", volumeValue: 330, unit: .milliliters,
            isNonAlcoholic: true).drinkEntry(using: originalResolver)
        let oldOption = try #require(WateredStore(entries: [original]).recentDrinkOptions(in: bundled).first)
        let revisedDrink = DrinkDefinition(id: "beer", name: "Beer", categoryID: "alcohol", sortOrder: 10,
            isRetired: false, hydrationContributionRule: .ratio(0), caffeine: .none,
            alcohol: .options(AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.05, 0.06],
                nonAlcoholic: NonAlcoholicPreparation(hydrationRatio: 0.9, maximumABV: 0.005))))
        let revised = DrinkCatalogue(schemaVersion: 4, version: "future", categories: bundled.categories, drinks: [revisedDrink])
        let repeated = try oldOption.drinkEntry(using: DrinkCatalogueSnapshotResolver(catalogue: revised))
        #expect(repeated.catalogueSnapshot.hydrationContribution == 297)
        #expect(repeated.catalogueSnapshot.catalogueVersion == "future")
        #expect(original.catalogueSnapshot.hydrationContribution == 313.5)
        let retiredPreparation = DrinkDefinition(id: "beer", name: "Beer", categoryID: "alcohol", sortOrder: 10,
            isRetired: false, hydrationContributionRule: .ratio(0), caffeine: .none,
            alcohol: .options(AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.05, 0.06])))
        let withoutPreparation = DrinkCatalogue(schemaVersion: 4, version: "future", categories: bundled.categories,
            drinks: [retiredPreparation])
        #expect(WateredStore(entries: [original]).recentDrinkOptions(in: withoutPreparation).isEmpty)
        let fourPercent = try AddDrinkDraft(drinkID: "beer", volumeValue: 330, unit: .milliliters,
            alcoholABV: 0.04).drinkEntry(using: originalResolver)
        #expect(WateredStore(entries: [fourPercent]).recentDrinkOptions(in: revised).isEmpty)
    }

    @Test func rejectsUnsupportedAndContradictorySelections() throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        let amount = DrinkAmount(value: 250, unit: .milliliters)
        for item in expected {
            for abv in [0, 0.0001, Double.nan, Double.infinity, -0.1, 1.1] {
                #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                    _ = try resolver.resolve(drinkID: item.id, amount: amount, alcoholABV: abv)
                }
            }
            #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                _ = try resolver.resolve(drinkID: item.id, amount: amount, isNonAlcoholic: true, alcoholABV: item.abv)
            }
            if !item.nonAlcoholic {
                #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                    _ = try resolver.resolve(drinkID: item.id, amount: amount, isNonAlcoholic: true)
                }
            }
        }
        #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
            _ = try resolver.resolve(drinkID: "still-water", amount: amount, isNonAlcoholic: true)
        }
        #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
            _ = try resolver.resolve(drinkID: "still-water", amount: amount, alcoholABV: 0.05)
        }
    }

    @Test func malformedConfigurationsFailValidation() throws {
        let bundled = try DrinkCatalogueLoader().load()
        let invalid = [
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: []),
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.04, 0.06]),
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.05, 0.05]),
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.06, 0.05]),
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.05, 1.1]),
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.05, .nan]),
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.04, 0.05],
                nonAlcoholic: NonAlcoholicPreparation(hydrationRatio: -1, maximumABV: 0.005)),
            AlcoholConfiguration(defaultABV: 0.05, supportedABVs: [0.04, 0.05],
                nonAlcoholic: NonAlcoholicPreparation(hydrationRatio: 0.95, maximumABV: 0.05))
        ]
        for configuration in invalid {
            let drink = DrinkDefinition(id: "test", name: "Test", categoryID: "alcohol", sortOrder: 0,
                isRetired: false, hydrationContributionRule: .ratio(0), caffeine: .none, alcohol: .options(configuration))
            let catalogue = DrinkCatalogue(schemaVersion: 4, version: "test", categories: bundled.categories, drinks: [drink])
            #expect(throws: DrinkCatalogue.ValidationError.invalidAlcoholConfiguration(drinkID: "test")) {
                try catalogue.validate()
            }
        }
        let source = try JSONEncoder().encode(try #require(bundled.drink(withID: "beer")))
        var object = try #require(JSONSerialization.jsonObject(with: source) as? [String: Any])
        var alcohol = try #require(object["alcohol"] as? [String: Any])
        alcohol["value"] = 0.05 // ABV cannot also be authored outside configuration.
        object["alcohol"] = alcohol
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DrinkDefinition.self, from: JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func savedFactsAndUnknownsSurviveWhileRepeatUsesCurrentPolicy() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let legacySnapshot = DrinkCatalogueSnapshot(drinkID: "wine", drinkName: "Previously recorded wine",
            caffeineVariant: .regular, shotCount: nil, hydrationContribution: -52.5, caffeineAmount: nil,
            catalogueVersion: "old", calculationVersion: "1", catalogueSchemaVersion: 1)
        let legacy = DrinkEntry(amount: DrinkAmount(value: 175, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: legacySnapshot)
        var entries = [legacy]
        for item in expected {
            for step in item.steps {
                entries.append(try AddDrinkDraft(drinkID: item.id, volumeValue: item.serving,
                    unit: .milliliters, alcoholABV: step).drinkEntry(using: resolver))
            }
            if item.nonAlcoholic {
                entries.append(try AddDrinkDraft(drinkID: item.id, volumeValue: item.serving,
                    unit: .milliliters, isNonAlcoholic: true).drinkEntry(using: resolver))
            }
        }
        for entry in entries { try DrinkEntryPersistence.save(entry, in: context) }
        let restored = try ModelContext(container).fetch(FetchDescriptor<PersistentDrinkEntry>()).compactMap { $0.drinkEntry() }
        #expect(restored.count == entries.count)
        for entry in entries {
            #expect(restored.first(where: { $0.id == entry.id })?.catalogueSnapshot == entry.catalogueSnapshot)
        }
        let options = WateredStore(entries: restored.filter { $0.id != legacy.id }).recentDrinkOptions(in: catalogue)
        #expect(options.count == entries.count - 1)
        for option in options {
            let repeated = try option.drinkEntry(using: resolver)
            #expect(!entries.contains(where: { $0.id == repeated.id }))
            #expect(repeated.catalogueSnapshot.isNonAlcoholic == option.isNonAlcoholic)
            #expect(repeated.catalogueSnapshot.alcoholABV == option.alcoholABV)
            #expect(repeated.catalogueSnapshot.catalogueVersion == catalogue.version)
        }
        let oldOption = try #require(WateredStore(entries: [legacy]).recentDrinkOptions(in: catalogue).first)
        let repeated = try oldOption.drinkEntry(using: resolver)
        #expect(repeated.catalogueSnapshot.hydrationContribution == 0)
        #expect(repeated.catalogueSnapshot.alcoholABV == 0.13)
        #expect(restored.first(where: { $0.id == legacy.id })?.catalogueSnapshot == legacySnapshot)
    }
}
