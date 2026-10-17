//
//  DrinkCatalogueLoaderTests.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkCatalogueLoaderTests {
    // GIVEN the catalogue resource bundled with the app,
    // WHEN the loader reads and validates it,
    // THEN the catalogue contains the expected active water definition.
    @Test func loadsBundledCatalogue() throws {
        let loader = DrinkCatalogueLoader()
        let catalogue = try loader.load()

        let water = try #require(
            catalogue.drink(withID: "still-water")
        )

        #expect(catalogue.schemaVersion == 1)
        #expect(!catalogue.version.isEmpty)
        #expect(water.categoryID == "water")
        #expect(!water.isRetired)
        #expect(catalogue.activeDrinks(inCategoryID: "water").contains(water))
    }
    
    // GIVEN malformed JSON or an object missing required catalogue fields,
    // WHEN the loader processes the data,
    // THEN it reports a decoding error instead of returning a catalogue.
    @Test(arguments: ["not valid JSON", "{}"])
    func rejectsUndecodableCatalogue(json: String) {
        let loader = DrinkCatalogueLoader()

        #expect(throws: DecodingError.self) {
            _ = try loader.load(from: Data(json.utf8))
        }
    }

    // GIVEN decodable catalogue JSON with an unsupported schema version,
    // WHEN the loader processes the data,
    // THEN it reports the validation error rather than exposing the catalogue.
    @Test func rejectsUnsupportedCatalogueSchema() {
        let json = """
        {
            "schemaVersion": 2,
            "version": "test-1",
            "categories": [],
            "drinks": []
        }
        """
        let loader = DrinkCatalogueLoader()
        let expectedError =
            DrinkCatalogue.ValidationError.unsupportedSchemaVersion(2)

        #expect(throws: expectedError) {
            _ = try loader.load(from: Data(json.utf8))
        }
    }
    
    // GIVEN the test bundle, which does not contain the app's catalogue resource,
    // WHEN the loader attempts to load its catalogue,
    // THEN it reports the explicit resource-not-found error.
    @Test func reportsMissingCatalogueResource() {
        let testBundle = Bundle(for: CatalogueTestBundleMarker.self)
        let loader = DrinkCatalogueLoader()

        #expect(throws: DrinkCatalogueLoader.LoadError.resourceNotFound) {
            _ = try loader.load(from: testBundle)
        }
    }
    
    // GIVEN the approved water definitions in the bundled catalogue,
    // WHEN the catalogue is loaded,
    // THEN all five drinks are active, correctly ordered and use the approved contribution ratios.
    @Test func loadsReviewedWaterDefinitions() throws {
        let catalogue = try DrinkCatalogueLoader().load()

        let expectedDrinks: [(id: String, ratio: Double)] = [
            ("still-water", 1.0),
            ("mineral-water", 1.0),
            ("sparkling-water", 1.0),
            ("infused-water", 1.0),
            ("coconut-water", 0.95)
        ]

        let activeWaterDrinks = catalogue.activeDrinks(
            inCategoryID: "water"
        )

        let actualIDs = activeWaterDrinks.map({ drink in
            return drink.id
        })

        let expectedIDs = expectedDrinks.map({ expectedDrink in
            return expectedDrink.id
        })

        #expect(actualIDs == expectedIDs)

        for expectedDrink in expectedDrinks {
            let drink = try #require(
                catalogue.drink(withID: expectedDrink.id)
            )

            #expect(
                drink.hydrationContributionRule ==
                    .ratio(expectedDrink.ratio)
            )
        }
    }
    
    // GIVEN the approved coffee definitions in the bundled catalogue,
    // WHEN the catalogue is loaded,
    // THEN the drinks have the expected order, contribution ratios and caffeine preparations,
    // with unreviewed caffeine amounts remaining explicitly unknown.
    @Test func loadsReviewedCoffeeDefinitions() throws {
        let catalogue = try DrinkCatalogueLoader().load()

        let expectedDrinks: [
            (id: String, ratio: Double, variant: CaffeineVariant)
        ] = [
            ("latte", 0.906, .regular),
            ("cappuccino", 0.91, .regular),
            ("iced-coffee", 0.99, .regular),
            ("espresso", 0.95, .regular),
            ("coffee-with-milk", 0.981, .regular),
            ("cold-brew", 0.99, .regular),
            ("frappe", 0.99, .regular),
            ("americano", 0.994, .regular),
            ("mocha", 0.862, .regular),
            ("decaf-coffee", 0.99, .decaf),
            ("turkish-coffee", 0.95, .regular)
        ]

        let activeCoffeeDrinks = catalogue.activeDrinks(
            inCategoryID: "coffee"
        )

        let actualIDs = activeCoffeeDrinks.map({ drink in
            return drink.id
        })

        let expectedIDs = expectedDrinks.map({ expectedDrink in
            return expectedDrink.id
        })
        #expect(actualIDs == expectedIDs)

        for expectedDrink in expectedDrinks {
            let drink = try #require(
                catalogue.drink(withID: expectedDrink.id)
            )

            #expect(
                drink.hydrationContributionRule ==
                    .ratio(expectedDrink.ratio)
            )
            #expect(drink.defaultCaffeineVariant == expectedDrink.variant)
            #expect(
                drink.caffeineOptions == [
                    CaffeineOption(
                        variant: expectedDrink.variant,
                        rule: .unknown
                    )
                ]
            )
        }
    }
}
// MARK: - Helpers

/// Identified the unit-test bundle separately from the application bundle
private final class CatalogueTestBundleMarker: NSObject {}
