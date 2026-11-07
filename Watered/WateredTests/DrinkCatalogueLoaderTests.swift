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

        #expect(catalogue.schemaVersion == 2)
        #expect(catalogue.version == "development-4")
        #expect(catalogue.drinks.count == 11)
        #expect(catalogue.categories == [
            DrinkCategory(id: "water", name: "Water", sortOrder: 10),
            DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 20)
        ])
        #expect(catalogue.drink(withID: "mineral-water") == nil)
        #expect(water.categoryID == "water")
        #expect(!water.isRetired)
        #expect(catalogue.activeDrinks(inCategoryID: "water").contains(water))
    }
    
    // GIVEN malformed JSON or an object missing required manifest fields,
    // WHEN the loader processes the data,
    // THEN it reports a decoding error instead of returning a catalogue.
    @Test(arguments: ["not valid JSON", "{}"])
    func rejectsUndecodableManifest(json: String) {
        let loader = DrinkCatalogueLoader()

        #expect(throws: DecodingError.self) {
            _ = try loader.load(
                from: Data(json.utf8),
                categoryData: { filename in
                    throw DrinkCatalogueLoader.LoadError.categoryResourceNotFound(filename)
                }
            )
        }
    }

    // GIVEN decodable catalogue JSON with an unsupported schema version,
    // WHEN the loader processes the data,
    // THEN it reports the validation error rather than exposing the catalogue.
    @Test func rejectsUnsupportedCatalogueSchema() {
        let json = """
        {
            "manifestVersion": 1,
            "schemaVersion": 3,
            "version": "test-1",
            "categories": []
        }
        """
        let loader = DrinkCatalogueLoader()
        let expectedError =
            DrinkCatalogue.ValidationError.unsupportedSchemaVersion(3)

        #expect(throws: expectedError) {
            _ = try loader.load(
                from: Data(json.utf8),
                categoryData: { filename in
                    throw DrinkCatalogueLoader.LoadError.categoryResourceNotFound(filename)
                }
            )
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
    // THEN all four drinks are active, correctly ordered and use the approved contribution ratios.
    @Test func loadsReviewedWaterDefinitions() throws {
        let catalogue = try DrinkCatalogueLoader().load()

        let expectedDrinks: [(id: String, ratio: Double)] = [
            ("still-water", 1.0),
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
    // with reviewed regular and decaf estimates.
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
            ("americano", 0.994, .regular)
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
                        rule: expectedDrink.id == "cold-brew" ? .perVolume(concentration: 50) :
                            expectedDrink.id == "coffee-with-milk" ? .perVolume(concentration: 40) : .perShot(amount: 60)
                    ),
                    CaffeineOption(variant: .decaf, rule: expectedDrink.id == "cold-brew" ? .perVolume(concentration: 5) :
                        expectedDrink.id == "coffee-with-milk" ? .perVolume(concentration: 2) : .perShot(amount: 5))
                ]
            )
        }
    }

    // Preparation changes retain cup volume and hydration while resolving caffeine independently.
    @Test func bundledCoffeePreparationsPreserveVolumeAndResolveCaffeine() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let shotDrinks: Set<String> = ["latte", "cappuccino", "espresso", "americano", "iced-coffee"]
        for drink in catalogue.activeDrinks(inCategoryID: "coffee") {
            if shotDrinks.contains(drink.id) {
                #expect(drink.shotConfiguration == ShotConfiguration(
                    supportedCounts: [0, 1, 2, 3, 4],
                    defaultCount: ["espresso", "cappuccino"].contains(drink.id) ? 1 : 2
                ))
            } else {
                #expect(drink.shotConfiguration == nil)
            }
            let counts: [Int?] = drink.shotConfiguration?.supportedCounts.map { Optional($0) } ?? [nil]
            for variant in CaffeineVariant.allCases {
                for count in counts {
                    let entry = try AddDrinkDraft(
                        drinkID: drink.id, volumeValue: 330, unit: .milliliters,
                        caffeineVariant: variant, shotCount: count
                    ).drinkEntry(using: resolver)
                    #expect(entry.amount.value == 330)
                    #expect(entry.catalogueSnapshot.caffeineVariant == variant)
                    #expect(entry.catalogueSnapshot.shotCount == count)
                    let regular = variant == .regular
                    let expected = count.map { Double($0) * (regular ? 60 : 5) }
                        ?? (drink.id == "cold-brew" ? (regular ? 165 : 16.5) : (regular ? 132 : 6.6))
                    #expect(abs(try #require(entry.catalogueSnapshot.caffeineAmount) - expected) < 0.000001)
                    #expect(entry.catalogueSnapshot.hydrationContribution ==
                        (try DrinkEstimateCalculator.hydrationContribution(for: entry.amount, rule: drink.hydrationContributionRule)))
                }
            }
        }
    }
}
// MARK: - Helpers

/// Identified the unit-test bundle separately from the application bundle
private final class CatalogueTestBundleMarker: NSObject {}
