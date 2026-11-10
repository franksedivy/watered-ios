import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkContentStructureTests {
    @Test func knownAbsenceAndUnknownResolveDifferently() throws {
        for (kind, expected) in [("none", Optional(0.0)), ("unknown", nil)] {
            let catalogue = try catalogue(caffeine: "{\"kind\":\"\(kind)\"}")
            let snapshot = try DrinkCatalogueSnapshotResolver(catalogue: catalogue).resolve(
                drinkID: "test", amount: DrinkAmount(value: 250, unit: .milliliters)
            )
            #expect(snapshot.caffeineAmount == expected)
            #expect(snapshot.hydrationContribution == 250)
            #expect(snapshot.catalogueSchemaVersion == 3)
            let encoded = try JSONEncoder().encode(catalogue)
            #expect(try JSONDecoder().decode(DrinkCatalogue.self, from: encoded) == catalogue)
            let json = try #require(String(data: encoded, encoding: .utf8))
            #expect(!json.contains("caffeineOptions"))
            #expect(!json.contains("defaultCaffeineVariant"))
        }
    }

    @Test func alcoholContentDoesNotSelectHydrationPolicy() throws {
        let alcohol = "{\"kind\":\"abv\",\"value\":0.05}"
        let ratioCatalogue = try catalogue(alcohol: alcohol)
        let alcoholCatalogue = try catalogue(alcohol: alcohol, hydration: "{\"kind\":\"alcohol\"}")
        let amount = DrinkAmount(value: 250, unit: .milliliters)
        let ratioSnapshot = try DrinkCatalogueSnapshotResolver(catalogue: ratioCatalogue).resolve(drinkID: "test", amount: amount)
        let alcoholSnapshot = try DrinkCatalogueSnapshotResolver(catalogue: alcoholCatalogue).resolve(drinkID: "test", amount: amount)
        #expect(ratioSnapshot.hydrationContribution == 250)
        #expect(alcoholSnapshot.hydrationContribution == 0)
        let data = try JSONEncoder().encode(alcoholCatalogue)
        #expect(try JSONDecoder().decode(DrinkCatalogue.self, from: data) == alcoholCatalogue)
        #expect(!String(decoding: data, as: UTF8.self).contains("defaultABV"))
    }

    @Test(arguments: [
        "{}", "null", "{\"kind\":\"missing\"}",
        "{\"kind\":\"none\",\"options\":[]}",
        "{\"kind\":\"unknown\",\"defaultVariant\":\"regular\"}",
        "{\"kind\":\"options\",\"options\":[]}",
        "{\"kind\":\"options\",\"defaultVariant\":\"regular\"}",
        "{\"kind\":\"options\",\"defaultVariant\":\"regular\",\"options\":[]}",
        "{\"kind\":\"options\",\"defaultVariant\":\"decaf\",\"options\":[{\"variant\":\"regular\",\"rule\":{\"kind\":\"unknown\"}}]}",
        "{\"kind\":\"options\",\"defaultVariant\":\"regular\",\"options\":[{\"variant\":\"regular\",\"rule\":{\"kind\":\"unknown\",\"amount\":0}}]}"
    ])
    func rejectsInvalidCaffeine(json: String) {
        #expect(throws: (any Error).self) { _ = try catalogue(caffeine: json) }
    }

    @Test(arguments: [
        "{}", "null", "{\"kind\":\"abv\"}",
        "{\"kind\":\"none\",\"value\":0.05}",
        "{\"kind\":\"unknown\",\"value\":0}",
        "{\"kind\":\"abv\",\"value\":-0.01}",
        "{\"kind\":\"abv\",\"value\":5}",
        "{\"kind\":\"abv\",\"value\":\"5%\"}"
    ])
    func rejectsInvalidAlcohol(json: String) {
        #expect(throws: DecodingError.self) { _ = try catalogue(alcohol: json) }
    }

    @Test(arguments: ["none", "unknown"])
    func alcoholHydrationRequiresABV(kind: String) {
        #expect(throws: DecodingError.self) {
            _ = try catalogue(alcohol: "{\"kind\":\"\(kind)\"}", hydration: "{\"kind\":\"alcohol\"}")
        }
    }

    @Test func rejectsDuplicateABVAndMixedLegacyFields() {
        #expect(throws: DecodingError.self) {
            _ = try catalogue(alcohol: "{\"kind\":\"abv\",\"value\":0.05}",
                              hydration: "{\"kind\":\"alcohol\",\"defaultABV\":0.06}")
        }
        #expect(throws: DecodingError.self) {
            _ = try catalogue(extra: ",\"caffeineOptions\":[]")
        }
        #expect(throws: DecodingError.self) {
            _ = try catalogue(extra: ",\"containsAlcohol\":false")
        }
        #expect(throws: DrinkCatalogue.ValidationError.invalidShotConfiguration(drinkID: "test")) {
            _ = try catalogue(extra: ",\"shotConfiguration\":{\"supportedCounts\":[0,1],\"defaultCount\":1}")
        }
    }

    @Test func schemaThreeRequiresContentInBothLoadingPaths() throws {
        let definition = """
        {"id":"test","name":"Test","categoryID":"test","sortOrder":0,"isRetired":false,
         "hydrationContributionRule":{"kind":"unknown"},
         "caffeineOptions":[{"variant":"regular","rule":{"kind":"unknown"}}],
         "defaultCaffeineVariant":"regular"}
        """
        for schema in [1, 2, 3] {
            let assembled = """
            {"schemaVersion":\(schema),"version":"test","categories":[{"id":"test","name":"Test","sortOrder":0}],"drinks":[\(definition)]}
            """
            let manifest = """
            {"manifestVersion":1,"schemaVersion":\(schema),"version":"test","categories":[{"id":"test","name":"Test","sortOrder":0,"file":"test.json"}]}
            """
            if schema == 3 {
                #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(DrinkCatalogue.self, from: Data(assembled.utf8)) }
                #expect(throws: DecodingError.self) {
                    _ = try DrinkCatalogueLoader().load(from: Data(manifest.utf8), categoryData: { _ in Data("[\(definition)]".utf8) })
                }
            } else {
                let decoded = try JSONDecoder().decode(DrinkCatalogue.self, from: Data(assembled.utf8))
                let loaded = try DrinkCatalogueLoader().load(from: Data(manifest.utf8), categoryData: { _ in Data("[\(definition)]".utf8) })
                #expect(decoded == loaded)
                #expect(decoded.drinks.first?.alcohol == .unknown)
            }
        }
        for key in ["caffeine", "alcohol"] {
            let data = try JSONEncoder().encode(catalogue())
            var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var drinks = try #require(object["drinks"] as? [[String: Any]])
            drinks[0].removeValue(forKey: key)
            object["drinks"] = drinks
            let missing = try JSONSerialization.data(withJSONObject: object)
            #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(DrinkCatalogue.self, from: missing) }
        }
    }

    @Test func oldWaterSnapshotSurvivesWhileRepeatUsesNewSchema() throws {
        let old = DrinkCatalogueSnapshot(
            drinkID: "still-water", drinkName: "Still water", caffeineVariant: .regular, shotCount: nil,
            hydrationContribution: 250, caffeineAmount: nil, catalogueVersion: "development-4",
            calculationVersion: "2", catalogueSchemaVersion: 2
        )
        let entry = DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
                               date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: old)
        let record = PersistentDrinkEntry(drinkEntry: entry)
        let restored = try #require(record.drinkEntry())
        let current = try DrinkCatalogueLoader().load()
        let recent = try #require(WateredStore(entries: [restored]).recentDrinkOptions(in: current).first)
        let repeated = try recent.drinkEntry(using: DrinkCatalogueSnapshotResolver(catalogue: current))
        #expect(record.drinkEntry()?.catalogueSnapshot == old)
        #expect(repeated.id != restored.id)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 0)
        #expect(repeated.catalogueSnapshot.catalogueSchemaVersion == current.schemaVersion)
        #expect(repeated.catalogueSnapshot.hydrationContribution == 250)
    }

    private func catalogue(
        caffeine: String = "{\"kind\":\"none\"}", alcohol: String = "{\"kind\":\"none\"}",
        hydration: String = "{\"kind\":\"ratio\",\"ratio\":1}", extra: String = ""
    ) throws -> DrinkCatalogue {
        let json = """
        {"schemaVersion":3,"version":"test","categories":[{"id":"test","name":"Test","sortOrder":0}],
         "drinks":[{"id":"test","name":"Test","categoryID":"test","sortOrder":0,"isRetired":false,
         "hydrationContributionRule":\(hydration),"caffeine":\(caffeine),"alcohol":\(alcohol)\(extra)}]}
        """
        let result = try JSONDecoder().decode(DrinkCatalogue.self, from: Data(json.utf8))
        try result.validate()
        return result
    }
}
