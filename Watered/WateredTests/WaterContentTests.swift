import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct WaterContentTests {
    @Test func bundleHasReviewedWaterForEveryDrinkAndPreparation() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        #expect(catalogue.drinks.count == 60)
        for drink in catalogue.drinks {
            #expect(drink.waterContent != .unknown)
            #expect(try resolver.resolve(drinkID: drink.id,
                amount: DrinkAmount(value: 250, unit: .milliliters)).waterAmount != nil)
            if drink.alcohol.configuration?.nonAlcoholic != nil {
                #expect(try resolver.resolve(drinkID: drink.id,
                    amount: DrinkAmount(value: 250, unit: .milliliters), isNonAlcoholic: true).waterAmount != nil)
            }
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func otherWaterIsSavedSeparatelyFromGoalCredit(unit: LiquidUnit) throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        for (id, fraction) in ["broth": 0.99, "miso": 0.97] {
            let snapshot = try resolver.resolve(drinkID: id, amount: amount)
            #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
            #expect(abs(try #require(snapshot.hydrationContribution) - volume * 0.95) < 0.000001)
            #expect(snapshot.caffeineAmount == 0)
            let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
            #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func reviewedWaterValuesAreCapturedWithoutChangingOldUnknowns(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let converted = Measurement(value: 330.0, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
        let amount = DrinkAmount(value: converted.value, unit: unit)
        let expected = ["still-water": 1.0, "sparkling-water": 1.0, "infused-water": 1.0, "coconut-water": 0.95]
        #expect(Set(catalogue.activeDrinks(inCategoryID: "water").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            #expect(catalogue.drink(withID: id)?.waterContent == .fraction(fraction))
            let snapshot = try resolver.resolve(drinkID: id, amount: amount)
            #expect(abs(try #require(snapshot.waterAmount) - 330 * fraction) < 0.000001)
            #expect(snapshot.caffeineAmount == 0)
            var old = snapshot
            old.waterAmount = nil
            let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: old)
            let record = PersistentDrinkEntry(drinkEntry: entry)
            let restored = try #require(record.drinkEntry())
            let recent = try #require(WateredStore(entries: [restored]).recentDrinkOptions(in: catalogue).first)
            let repeated = try recent.drinkEntry(using: resolver)
            #expect(abs(try #require(repeated.catalogueSnapshot.waterAmount) - 330 * fraction) < 0.000001)
            #expect(record.drinkEntry()?.catalogueSnapshot.waterAmount == nil)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func coffeeWaterIsFixedAcrossVariantsAndEverySupportedShotCount(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected = ["latte": 0.90, "cappuccino": 0.90, "iced-coffee": 0.98,
                        "espresso": 0.92, "coffee-with-milk": 0.98, "cold-brew": 0.98, "americano": 0.98]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(Set(catalogue.activeDrinks(inCategoryID: "coffee").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            let definition = try #require(catalogue.drink(withID: id))
            #expect(definition.waterContent == .fraction(fraction))
            let counts: [Int?] = definition.shotConfiguration?.supportedCounts.map { Optional($0) } ?? [nil]
            for variant in [CaffeineVariant.regular, .decaf] {
                for count in counts {
                    let snapshot = try resolver.resolve(drinkID: id, amount: amount,
                        caffeineVariant: variant, shotCount: count)
                    #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
                    if let count {
                        #expect(snapshot.caffeineAmount == Double(count) * (variant == .regular ? 60 : 5))
                    }
                }
            }
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func teaWaterIsFixedAcrossEverySupportedCaffeineVariant(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected = ["black-tea": 1.0, "green-tea": 1.0, "white-tea": 1.0, "herbal-tea": 1.0,
                        "matcha": 0.99, "matcha-latte": 0.92, "bubble-milk-tea": 0.93,
                        "bubble-fruit-tea": 0.95, "yerba-mate": 0.99, "iced-tea": 0.95]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(Set(catalogue.activeDrinks(inCategoryID: "tea").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            let definition = try #require(catalogue.drink(withID: id))
            #expect(definition.waterContent == .fraction(fraction))
            for option in definition.caffeineOptions {
                let snapshot = try resolver.resolve(drinkID: id, amount: amount, caffeineVariant: option.variant)
                #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
                #expect(snapshot.caffeineAmount == (try DrinkEstimateCalculator.caffeineAmount(
                    for: amount, rule: option.rule)))
                let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
                #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
            }
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func juiceWaterIsCapturedSeparatelyFromGoalCredit(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected = ["fruit-juice": 0.90, "vegetable-juice": 0.95, "smoothie": 0.85, "aloe-vera-drink": 0.95]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(Set(catalogue.activeDrinks(inCategoryID: "juices").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            #expect(catalogue.drink(withID: id)?.waterContent == .fraction(fraction))
            let snapshot = try resolver.resolve(drinkID: id, amount: amount)
            #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
            #expect(snapshot.caffeineAmount == 0)
            if id == "aloe-vera-drink" {
                #expect(abs(try #require(snapshot.hydrationContribution) - volume * 0.90) < 0.000001)
                #expect(snapshot.waterAmount != snapshot.hydrationContribution)
            }
            let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
            #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func softDrinkWaterIsFixedAcrossCaffeineVariantsAndSavedSeparately(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected = ["cola": 0.93, "lemonade": 0.96, "tonic-water": 0.95,
                        "fruit-soda": 0.95, "ginger-beer": 0.93, "squash": 0.98]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(Set(catalogue.activeDrinks(inCategoryID: "soft-drinks").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            let definition = try #require(catalogue.drink(withID: id))
            #expect(definition.waterContent == .fraction(fraction))
            for option in definition.caffeineOptions {
                let snapshot = try resolver.resolve(drinkID: id, amount: amount, caffeineVariant: option.variant)
                #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
                #expect(abs(try #require(snapshot.hydrationContribution) - volume * (id == "squash" ? 0.95 : 0.90)) < 0.000001)
                let caffeine = id == "cola" && option.variant == .regular ? volume * 0.10 : 0
                #expect(abs(try #require(snapshot.caffeineAmount) - caffeine) < 0.000001)
                let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
                #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
            }
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func wellnessWaterIsSavedIndependentlyOfCaffeineAndUnknownAlcohol(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected = ["kombucha": 0.98, "vitamin-drink": 0.97, "cbd-drink": 0.98]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(Set(catalogue.activeDrinks(inCategoryID: "wellness").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            let definition = try #require(catalogue.drink(withID: id))
            #expect(definition.waterContent == .fraction(fraction))
            let snapshot = try resolver.resolve(drinkID: id, amount: amount)
            #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
            #expect(abs(try #require(snapshot.hydrationContribution) - volume * 0.95) < 0.000001)
            #expect(abs(try #require(snapshot.caffeineAmount) - (id == "kombucha" ? volume * 0.04 : 0)) < 0.000001)
            if id == "kombucha" {
                #expect(definition.alcohol == .unknown)
            }
            let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
            #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func sportsWaterUsesPreparedVolumeAndIsSavedSeparately(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected = ["energy-drink": 0.93, "sports-drink": 0.96,
                        "electrolyte-drink": 0.99, "protein-shake": 0.90]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(Set(catalogue.activeDrinks(inCategoryID: "sports-energy").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            let definition = try #require(catalogue.drink(withID: id))
            #expect(definition.waterContent == .fraction(fraction))
            let snapshot = try resolver.resolve(drinkID: id, amount: amount)
            #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
            let goalRatio = id == "energy-drink" || id == "protein-shake" ? 0.90 : 0.95
            #expect(abs(try #require(snapshot.hydrationContribution) - volume * goalRatio) < 0.000001)
            #expect(abs(try #require(snapshot.caffeineAmount) - (id == "energy-drink" ? volume * 0.32 : 0)) < 0.000001)
            let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
            #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func milkWaterIsSavedSeparatelyFromGoalCreditAndCocoaCaffeine(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected = ["milk": 0.90, "oat-milk": 0.92, "soy-milk": 0.94,
                        "almond-milk": 0.97, "coconut-milk": 0.97, "rice-milk": 0.90,
                        "kefir": 0.90, "drinking-yoghurt": 0.85, "milkshake": 0.85,
                        "chocolate-milk": 0.87, "hot-chocolate": 0.85, "ayran": 0.95]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        #expect(Set(catalogue.activeDrinks(inCategoryID: "milk-alternatives").map(\.id)) == Set(expected.keys))
        for (id, fraction) in expected {
            let definition = try #require(catalogue.drink(withID: id))
            #expect(definition.waterContent == .fraction(fraction))
            let snapshot = try resolver.resolve(drinkID: id, amount: amount)
            #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
            let cocoa = id == "chocolate-milk" || id == "hot-chocolate"
            #expect(abs(try #require(snapshot.caffeineAmount) - (cocoa ? volume * 0.02 : 0)) < 0.000001)
            if id == "chocolate-milk" {
                #expect(abs(try #require(snapshot.hydrationContribution) - volume * 0.85) < 0.000001)
                #expect(snapshot.waterAmount != snapshot.hydrationContribution)
            }
            let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
            #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func alcoholWaterFollowsEveryStrengthAndPreservesSavedFacts(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let expected: [String: [Double]] = [
            "beer": [0.94, 0.935, 0.93, 0.925, 0.92],
            "cider": [0.92, 0.915, 0.91, 0.905, 0.90],
            "wine": [0.89, 0.88, 0.87, 0.86, 0.85],
            "cocktail": [0.90, 0.85, 0.80, 0.75, 0.70],
            "sparkling-wine": [0.90, 0.89, 0.88, 0.87, 0.86],
            "fortified-wine": [0.82, 0.80, 0.78, 0.76, 0.74],
            "spirits": [0.72, 0.63, 0.54, 0.44],
            "liqueur": [0.70, 0.65, 0.60, 0.55, 0.50, 0.45]]
        let nonAlcoholic = ["beer": 0.97, "cider": 0.95, "wine": 0.97,
                            "cocktail": 0.95, "sparkling-wine": 0.97]
        let amount = DrinkAmount(value: 8, unit: unit)
        let volume = amount.volume.converted(to: .milliliters).value
        for (id, fractions) in expected {
            let definition = try #require(catalogue.drink(withID: id))
            let configuration = try #require(definition.alcohol.configuration)
            for (abv, fraction) in zip(configuration.supportedABVs, fractions) {
                let snapshot = try resolver.resolve(drinkID: id, amount: amount, alcoholABV: abv)
                #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
                #expect(snapshot.alcoholABV == abv)
                #expect(snapshot.hydrationContribution == 0)
                let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
                #expect(PersistentDrinkEntry(drinkEntry: entry).drinkEntry()?.catalogueSnapshot == snapshot)
            }
            if let fraction = nonAlcoholic[id] {
                let snapshot = try resolver.resolve(drinkID: id, amount: amount, isNonAlcoholic: true)
                #expect(abs(try #require(snapshot.waterAmount) - volume * fraction) < 0.000001)
                #expect(snapshot.alcoholABV == nil)
                #expect(snapshot.alcoholABVUpperBound == 0.005)
            }
        }
        var old = try resolver.resolve(drinkID: "beer", amount: amount, alcoholABV: 0.06)
        old.waterAmount = 1
        let entry = DrinkEntry(amount: amount, date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: old)
        let record = PersistentDrinkEntry(drinkEntry: entry)
        let restored = try #require(record.drinkEntry())
        let recent = try #require(WateredStore(entries: [restored]).recentDrinkOptions(in: catalogue).first)
        let repeated = try recent.drinkEntry(using: resolver)
        #expect(abs(try #require(repeated.catalogueSnapshot.waterAmount) - volume * 0.92) < 0.000001)
        #expect(record.drinkEntry()?.catalogueSnapshot.waterAmount == 1)
    }

    @Test func alcoholWaterRejectsIncompleteOrIncompatibleTables() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let encoded = try JSONEncoder().encode(catalogue)
        #expect(try JSONDecoder().decode(DrinkCatalogue.self, from: encoded) == catalogue)
        for mutation in 0..<5 {
            var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            var drinks = try #require(object["drinks"] as? [[String: Any]])
            let index = try #require(drinks.firstIndex(where: { $0["id"] as? String == "beer" }))
            var water = try #require(drinks[index]["waterContent"] as? [String: Any])
            var options = try #require(water["options"] as? [[String: Any]])
            switch mutation {
            case 0: options.removeLast()
            case 1: options[0]["abv"] = 0.03
            case 2: water.removeValue(forKey: "nonAlcoholic")
            case 3: object["schemaVersion"] = 5
            default: drinks[index]["alcohol"] = ["kind": "none"]
            }
            water["options"] = options
            drinks[index]["waterContent"] = water
            object["drinks"] = drinks
            let decoded = try JSONDecoder().decode(DrinkCatalogue.self,
                from: JSONSerialization.data(withJSONObject: object))
            #expect(throws: DrinkCatalogue.ValidationError.self) { try decoded.validate() }
        }
        let content = WaterContent.alcoholOptions([.init(abv: 0.05, fraction: 0.93)], nonAlcoholic: nil)
        #expect(throws: DrinkEstimateCalculator.CalculationError.self) {
            try DrinkEstimateCalculator.waterAmount(for: DrinkAmount(value: 250, unit: .milliliters), content: content, alcoholABV: 0.06)
        }
    }

    @Test(arguments: [#"{"kind":"alcoholOptions","options":[]}"#,
        #"{"kind":"alcoholOptions","options":[{"abv":0.05,"fraction":1.1}]}"#,
        #"{"kind":"alcoholOptions","options":[{"abv":0.05,"fraction":0.93},{"abv":0.05,"fraction":0.92}]}"#,
        #"{"kind":"fraction"}"#, #"{"kind":"fraction","value":null}"#,
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
