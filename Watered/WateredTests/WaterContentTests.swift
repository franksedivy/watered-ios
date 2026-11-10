import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct WaterContentTests {
    @Test func bundleLeavesEveryUnreviewedWaterEstimateUnknown() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        #expect(catalogue.drinks.count == 60)
        for drink in catalogue.drinks {
            #expect(drink.waterContent == .unknown)
            #expect(try resolver.resolve(drinkID: drink.id,
                amount: DrinkAmount(value: 330, unit: .milliliters)).waterAmount == nil)
            if drink.alcohol.configuration?.nonAlcoholic != nil {
                #expect(try resolver.resolve(drinkID: drink.id,
                    amount: DrinkAmount(value: 330, unit: .milliliters), isNonAlcoholic: true).waterAmount == nil)
            }
        }
    }

    @Test(arguments: [#"{"kind":"fraction"}"#, #"{"kind":"fraction","value":null}"#,
        #"{"kind":"fraction","value":-0.1}"#, #"{"kind":"fraction","value":1.1}"#,
        #"{"kind":"unknown","value":0}"#, #"{"kind":"none"}"#,
        #"{"kind":"fraction","value":0.9,"extra":true}"#])
    func malformedContentIsRejected(json: String) {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(WaterContent.self, from: Data(json.utf8))
        }
    }

    @Test func schemaFiveRequiresExplicitContentAndLegacyMissingStaysUnknown() throws {
        let original = catalogue(.fraction(0.9))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var drinks = try #require(json["drinks"] as? [[String: Any]])
        drinks[0].removeValue(forKey: "waterContent")
        json["drinks"] = drinks
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DrinkCatalogue.self, from: JSONSerialization.data(withJSONObject: json))
        }
        // Exercise the manifest/category-file loader as well as monolithic decoding.
        let manifest = Data(#"{"manifestVersion":1,"schemaVersion":5,"version":"test","categories":[{"id":"test","name":"Test","sortOrder":0,"file":"test.json"}]}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try DrinkCatalogueLoader().load(from: manifest, categoryData: { _ in
                try JSONSerialization.data(withJSONObject: drinks)
            })
        }
        json["schemaVersion"] = 4
        let legacy = try JSONDecoder().decode(DrinkCatalogue.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.drinks.first?.waterContent == .unknown)
        #expect(try JSONDecoder().decode(DrinkCatalogue.self, from: JSONEncoder().encode(original)) == original)
    }

    @Test(arguments: LiquidUnit.allCases)
    func capturesWaterIndependentlyAtFullVolumePrecision(unit: LiquidUnit) throws {
        let amount = DrinkAmount(value: 8, unit: unit)
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue(.fraction(0.9)))
        let snapshot = try resolver.resolve(drinkID: "test-drink", amount: amount)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(abs(try #require(snapshot.waterAmount) - volume * 0.9) < 0.0000001)
        #expect(snapshot.hydrationContribution == 0)
        #expect(snapshot.caffeineAmount == 0)
        #expect(try DrinkEstimateCalculator.waterAmount(for: amount, content: .fraction(0)) == 0)
        #expect(try DrinkEstimateCalculator.waterAmount(for: amount, content: .fraction(1)) == volume)
        #expect(try DrinkEstimateCalculator.waterAmount(for: amount, content: .unknown) == nil)
    }

    @Test(arguments: [-0.1, 1.1, Double.nan, Double.infinity])
    func invalidFractionsAreRejectedInMemory(value: Double) {
        #expect(throws: DrinkCatalogue.ValidationError.self) { try catalogue(.fraction(value)).validate() }
        #expect(throws: DrinkEstimateCalculator.CalculationError.self) {
            _ = try DrinkEstimateCalculator.waterAmount(for: DrinkAmount(value: 330, unit: .milliliters), content: .fraction(value))
        }
    }

    @Test(arguments: [0.0, -1, Double.nan, Double.infinity])
    func invalidAmountsNeverResolveEvenUnknownWater(value: Double) {
        for content in [WaterContent.unknown, .fraction(0.9)] {
            #expect(throws: DrinkEstimateCalculator.CalculationError.self) {
                _ = try DrinkEstimateCalculator.waterAmount(for: DrinkAmount(value: value, unit: .milliliters), content: content)
            }
        }
    }

    @Test func diskReopenPreservesWaterAndRepeatsCaptureNewRules() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("water.store")
        let amount = DrinkAmount(value: 330, unit: .milliliters)
        let entries = try [WaterContent.unknown, .fraction(0), .fraction(0.9)].map { content in
            DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000),
                catalogueSnapshot: try DrinkCatalogueSnapshotResolver(catalogue: catalogue(content))
                    .resolve(drinkID: "test-drink", amount: amount))
        }
        try save(entries, at: url)
        let restored = try read(at: url)
        for entry in entries {
            #expect(restored.first { $0.id == entry.id }?.catalogueSnapshot == entry.catalogueSnapshot)
        }
        let updated = catalogue(.fraction(0.8))
        let old = try #require(restored.first { $0.catalogueSnapshot.waterAmount == 297 })
        let recent = try #require(WateredStore(entries: [old]).recentDrinkOptions(in: updated).first)
        let repeated = try recent.drinkEntry(using: DrinkCatalogueSnapshotResolver(catalogue: updated))
        #expect(repeated.id != old.id)
        #expect(repeated.catalogueSnapshot.waterAmount == 264)
        #expect(old.catalogueSnapshot.waterAmount == 297)
        try save([repeated], at: url)
        #expect(try read(at: url).first { $0.id == old.id }?.catalogueSnapshot.waterAmount == 297)
    }

    @Test func oldRowsStayUnknownAndInvalidSavedWaterIsRejected() throws {
        let snapshot = DrinkCatalogueSnapshot(drinkID: "retired", drinkName: "Old drink",
            caffeineVariant: .regular, shotCount: nil, hydrationContribution: -20, caffeineAmount: nil,
            catalogueVersion: "old", calculationVersion: "1", catalogueSchemaVersion: nil)
        let record = PersistentDrinkEntry(drinkEntry: DrinkEntry(amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot))
        #expect(try #require(record.drinkEntry()).catalogueSnapshot.waterAmount == nil)
        for value in [-1.0, 331, Double.nan, Double.infinity] {
            record.waterAmount = value
            #expect(record.drinkEntry() == nil)
        }
        record.waterAmount = 0
        #expect(try #require(record.drinkEntry()).catalogueSnapshot.waterAmount == 0)
        #expect(record.drinkEntry()?.catalogueSnapshot.hydrationContribution == -20)
    }

    private func catalogue(_ content: WaterContent) -> DrinkCatalogue {
        DrinkCatalogue(schemaVersion: 5, version: "synthetic-water-test",
            categories: [DrinkCategory(id: "test", name: "Test", sortOrder: 0)],
            drinks: [DrinkDefinition(id: "test-drink", name: "Synthetic drink", categoryID: "test",
                sortOrder: 0, isRetired: false, hydrationContributionRule: .ratio(0),
                caffeine: .none, alcohol: .none, waterContent: content)])
    }

    private func save(_ entries: [DrinkEntry], at url: URL) throws {
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        for entry in entries { try DrinkEntryPersistence.save(entry, in: context) }
    }

    private func read(at url: URL) throws -> [DrinkEntry] {
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        return try ModelContext(container).fetch(FetchDescriptor<PersistentDrinkEntry>()).map {
            try #require($0.drinkEntry())
        }
    }
}
