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
    
    // GIVEN drinks sharing a display name, when one is requested by ID,
    // THEN lookup returns the matching definition rather than the first drink.
    @Test func catalogueFindsDrinkByID() throws {
        let expectedDrink = DrinkDefinition(
            id: "latte",
            name: "Coffee",
            categoryID: "coffee",
            sortOrder: 20,
            isRetired: false
        )

        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "americano",
                    name: "Coffee",
                    categoryID: "coffee",
                    sortOrder: 10,
                    isRetired: false
                ),
                expectedDrink
            ]
        )

        try catalogue.validate()

        #expect(catalogue.drink(withID: "latte") == expectedDrink)
    }
    
    // GIVEN a populated catalogue, when an unknown drink ID is requested,
    // THEN lookup returns nil rather than substituting another drink.
    @Test func catalogueReturnsNilForUnknownDrinkID() throws {
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
                )
            ]
        )

        try catalogue.validate()

        #expect(catalogue.drink(withID: "missing-drink") == nil)
    }
    
    // GIVEN a retired drink in the catalogue, when requested by ID,
    // THEN lookup returns its definition despite its retirement status.
    @Test func catalogueFindsRetiredDrinkByID() throws {
        let retiredDrink = DrinkDefinition(
            id: "latte",
            name: "Latte",
            categoryID: "coffee",
            sortOrder: 10,
            isRetired: true
        )

        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [retiredDrink]
        )

        try catalogue.validate()

        #expect(catalogue.drink(withID: "latte") == retiredDrink)
    }
    
    // GIVEN unordered drinks across categories, including a retired drink,
    // WHEN active coffee drinks are requested,
    // THEN only active coffee drinks are returned in their configured order.
    @Test func catalogueFiltersAndOrdersActiveDrinks() throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10),
                DrinkCategory(id: "tea", name: "Tea", sortOrder: 20)
            ],
            drinks: [
                DrinkDefinition(
                    id: "latte", name: "Latte", categoryID: "coffee",
                    sortOrder: 20, isRetired: false
                ),
                DrinkDefinition(
                    id: "green-tea", name: "Green tea", categoryID: "tea",
                    sortOrder: 5, isRetired: false
                ),
                DrinkDefinition(
                    id: "old-coffee", name: "Old coffee", categoryID: "coffee",
                    sortOrder: 1, isRetired: true
                ),
                DrinkDefinition(
                    id: "espresso", name: "Espresso", categoryID: "coffee",
                    sortOrder: 10, isRetired: false
                )
            ]
        )

        try catalogue.validate()

        let selectedDrinks = catalogue.activeDrinks(inCategoryID: "coffee")
        let selectedIDs = selectedDrinks.map({ drink in
            return drink.id
        })

        #expect(selectedIDs == ["espresso", "latte"])
    }
    
    // GIVEN drinks with equal sort positions and matching display names,
    // WHEN active drinks are requested,
    // THEN their stable IDs determine the order, regardless of input order.
    @Test func catalogueOrdersEqualPositionsByDrinkID() throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "latte", name: "Coffee", categoryID: "coffee",
                    sortOrder: 10, isRetired: false
                ),
                DrinkDefinition(
                    id: "espresso", name: "Coffee", categoryID: "coffee",
                    sortOrder: 10, isRetired: false
                )
            ]
        )

        try catalogue.validate()

        let selectedDrinks = catalogue.activeDrinks(inCategoryID: "coffee")
        let selectedIDs = selectedDrinks.map({ drink in
            return drink.id
        })

        #expect(selectedIDs == ["espresso", "latte"])
    }
    
    // GIVEN active, retired-only and empty categories,
    // WHEN categories without available drinks are requested,
    // THEN selection returns an empty list, including for unknown categories.
    @Test func catalogueReturnsEmptySelectionWhenNoActiveDrinksMatch() throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10),
                DrinkCategory(id: "tea", name: "Tea", sortOrder: 20),
                DrinkCategory(id: "water", name: "Water", sortOrder: 30)
            ],
            drinks: [
                DrinkDefinition(
                    id: "espresso", name: "Espresso", categoryID: "coffee",
                    sortOrder: 10, isRetired: false
                ),
                DrinkDefinition(
                    id: "green-tea", name: "Green tea", categoryID: "tea",
                    sortOrder: 10, isRetired: true
                )
            ]
        )

        try catalogue.validate()

        #expect(catalogue.activeDrinks(inCategoryID: "tea").isEmpty)
        #expect(catalogue.activeDrinks(inCategoryID: "water").isEmpty)
        #expect(catalogue.activeDrinks(inCategoryID: "missing-category").isEmpty)
    }
}
