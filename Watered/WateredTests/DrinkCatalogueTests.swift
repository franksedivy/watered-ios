//
//  DrinkCatalogueTests.swift
//  Watered
//
//  Created by Frank Sedivy on 07/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkCatalogueTests {
    
    // GIVEN catalogue JSON containing a category and a drink, when decoded,
    // THEN its versions, category and drink definitions retain their values.
    @Test func catalogueDecodesCateforiesAndDrinks() throws {
        let json = """
        {
            "schemaVersion": 1,
            "version": "test-1",
            "categories": [
                {
                    "id": "coffee",
                    "name": "Coffee",
                    "sortOrder": 10
                }
            ],
            "drinks": [
                {
                    "id": "latte",
                    "name": "Latte",
                    "categoryID": "coffee",
                    "sortOrder": 20,
                    "isRetired": false
                }
            ]
        }
        """
        
        let catalogue = try JSONDecoder().decode(
            DrinkCatalogue.self,
            from: Data(json.utf8)
        )
        
        #expect(catalogue.schemaVersion == 1)
        #expect(catalogue.version == "test-1")
        #expect(catalogue.categories == [
            DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
        ])
        #expect(catalogue.drinks == [
            DrinkDefinition(
                id: "latte",
                name: "Latte",
                categoryID: "coffee",
                sortOrder: 20,
                isRetired: false
            )
        ])
    }
    
    // GIVEN a catalogue with an unsupported schema version, when validated,
    // THEN validation reports the exact version it cannot support.
    @Test func catalogueRejectsUnsupportedSchemaVersion() {
        let catalogue = DrinkCatalogue(
            schemaVersion: 2,
            version: "test-2",
            categories: [],
            drinks: []
        )

        let expectedError =
            DrinkCatalogue.ValidationError.unsupportedSchemaVersion(2)

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
    
    // GIVEN categories sharing an ID, when the catalogue is validated,
    // THEN validation reports the duplicated identifier.
    @Test func catalogueRejectsDuplicateCategoryIDs() {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10),
                DrinkCategory(id: "coffee", name: "Another name", sortOrder: 20)
            ],
            drinks: []
        )

        let expectedError =
            DrinkCatalogue.ValidationError.duplicateCategoryID("coffee")

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }

    // GIVEN categories with distinct IDs, when the catalogue is validated,
    // THEN validation succeeds.
    @Test func catalogueAcceptsDistinctCategoryIDs() throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "water", name: "Water", sortOrder: 10),
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 20)
            ],
            drinks: []
        )

        try catalogue.validate()
    }
    
    // GIVEN active and retired drinks sharing an ID, when validated,
    // THEN the catalogue reports the duplicated drink identifier.
    @Test func catalogueRejectsDuplicateDrinkIDs() {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "latte",
                    name: "Latte",
                    categoryID: "coffee",
                    sortOrder: 10,
                    isRetired: true
                ),
                DrinkDefinition(
                    id: "latte",
                    name: "Replacement latte",
                    categoryID: "coffee",
                    sortOrder: 20,
                    isRetired: false
                )
            ]
        )

        let expectedError =
            DrinkCatalogue.ValidationError.duplicateDrinkID("latte")

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
    
    // GIVEN a drink referencing an unknown category, when validated,
    // THEN the error identifies the drink and its invalid category reference.
    @Test func catalogueRejectsUnknownCategoryReference() {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "latte",
                    name: "Latte",
                    categoryID: "cofee",
                    sortOrder: 10,
                    isRetired: false
                )
            ]
        )

        let expectedError =
            DrinkCatalogue.ValidationError.unknownCategoryID(
                drinkID: "latte",
                categoryID: "cofee"
            )

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
    
    // GIVEN distinct drinks referencing an existing category, when validated,
    // THEN both active and retired definitions are accepted.
    @Test func catalogueAcceptsValidDrinkDefinitions() throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "latte",
                    name: "Latte",
                    categoryID: "coffee",
                    sortOrder: 10,
                    isRetired: false
                ),
                DrinkDefinition(
                    id: "cappuccino",
                    name: "Cappuccino",
                    categoryID: "coffee",
                    sortOrder: 20,
                    isRetired: true
                )
            ]
        )

        try catalogue.validate()
    }
}
