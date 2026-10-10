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
}
// MARK: - Helpers

/// Identified the unit-test bundle separately from the application bundle
private final class CatalogueTestBundleMarker: NSObject {}
