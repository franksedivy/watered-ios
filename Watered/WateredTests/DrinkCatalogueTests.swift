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
                    "hydrationContributionRule": {
                        "kind": "unknown"
                    },
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
    
    // GIVEN unordered categories with distinct sort positions and no drinks,
    // WHEN ordered categories are requested,
    // THEN all categories are returned in their configured order.
    @Test func catalogueOrdersCategoriesBySortPosition() throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "tea", name: "Tea", sortOrder: 30),
                DrinkCategory(id: "water", name: "Water", sortOrder: 10),
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 20)
            ],
            drinks: []
        )

        try catalogue.validate()

        let orderedIDs = catalogue.orderedCategories.map({ category in
            return category.id
        })

        #expect(orderedIDs == ["water", "coffee", "tea"])
    }
    
    // GIVEN categories with equal sort positions and matching display names,
    // WHEN ordered categories are requested,
    // THEN their stable IDs determine the order, regardless of input order.
    @Test func catalogueOrdersEqualCategoryPositionsByID() throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "tea", name: "Drinks", sortOrder: 10),
                DrinkCategory(id: "coffee", name: "Drinks", sortOrder: 10)
            ],
            drinks: []
        )

        try catalogue.validate()

        let orderedIDs = catalogue.orderedCategories.map({ category in
            return category.id
        })

        #expect(orderedIDs == ["coffee", "tea"])
    }
    
    // GIVEN drink JSON containing a default serving volume in millilitres,
    // WHEN the definition is decoded,
    // THEN the supplied default volume is preserved.
    @Test func drinkDefinitionDecodesDefaultVolume() throws {
        let json = """
        {
            "id": "espresso",
            "name": "Espresso",
            "categoryID": "coffee",
            "sortOrder": 10,
            "hydrationContributionRule": {
                "kind": "unknown"
            },
            "isRetired": false,
            "defaultVolume": 30
        }
        """

        let drink = try JSONDecoder().decode(
            DrinkDefinition.self,
            from: Data(json.utf8)
        )

        #expect(drink.defaultVolume == 30)
    }
    
    // GIVEN drink JSON without a default serving volume,
    // WHEN the definition is decoded,
    // THEN its default volume is nil.
    @Test func drinkDefinitionDecodesWithoutDefaultVolume() throws {
        let json = """
        {
            "id": "espresso",
            "name": "Espresso",
            "categoryID": "coffee",
            "sortOrder": 10,
            "hydrationContributionRule": {
                "kind": "unknown"
            },
            "isRetired": false
        }
        """

        let drink = try JSONDecoder().decode(
            DrinkDefinition.self,
            from: Data(json.utf8)
        )

        #expect(drink.defaultVolume == nil)
    }
    
    // GIVEN a drink with a zero, negative or non-finite default volume,
    // WHEN the catalogue is validated,
    // THEN validation rejects the volume and identifies the drink.
    @Test(arguments: [
        0.0,
        -30.0,
        Double.infinity,
        -Double.infinity,
        Double.nan
    ])
    func catalogueRejectsInvalidDefaultVolume(defaultVolume: Double) {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "espresso",
                    name: "Espresso",
                    categoryID: "coffee",
                    sortOrder: 10,
                    isRetired: false,
                    defaultVolume: defaultVolume
                )
            ]
        )

        let expectedError =
            DrinkCatalogue.ValidationError.invalidDefaultVolume(
                drinkID: "espresso"
            )

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
    
    // GIVEN a drink with a positive, finite default volume,
    // WHEN the catalogue is validated,
    // THEN validation accepts the volume, including fractional values.
    @Test(arguments: [0.5, 30.0, 330.5])
    func catalogueAcceptsValidDefaultVolume(defaultVolume: Double) throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "espresso",
                    name: "Espresso",
                    categoryID: "coffee",
                    sortOrder: 10,
                    isRetired: false,
                    defaultVolume: defaultVolume
                )
            ]
        )

        try catalogue.validate()
    }
    
    // GIVEN drink JSON containing an explicit ratio contribution rule,
    // WHEN the definition is decoded,
    // THEN the nested rule and its value are preserved.
    @Test func drinkDefinitionDecodesHydrationContributionRule() throws {
        let json = """
        {
            "id": "still-water",
            "name": "Still water",
            "categoryID": "water",
            "sortOrder": 10,
            "isRetired": false,
            "hydrationContributionRule": {
                "kind": "ratio",
                "ratio": 1.0
            }
        }
        """

        let drink = try JSONDecoder().decode(
            DrinkDefinition.self,
            from: Data(json.utf8)
        )

        #expect(drink.hydrationContributionRule == .ratio(1.0))
    }
    
    // GIVEN drink JSON without a hydration contribution rule,
    // WHEN decoding is attempted,
    // THEN decoding fails instead of supplying an unknown rule.
    @Test func drinkDefinitionRejectsMissingHydrationContributionRule() {
        let json = """
        {
            "id": "still-water",
            "name": "Still water",
            "categoryID": "water",
            "sortOrder": 10,
            "isRetired": false
        }
        """

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                DrinkDefinition.self,
                from: Data(json.utf8)
            )
        }
    }
    
    // GIVEN an alcohol rule with an ABV between zero and one inclusive,
    // WHEN the catalogue is validated,
    // THEN validation accepts both boundaries and an intermediate value.
    @Test(arguments: [0.0, 0.05, 1.0])
    func catalogueAcceptsValidDefaultABV(defaultABV: Double) throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "alcohol", name: "Alcohol", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "test-drink",
                    name: "Test drink",
                    categoryID: "alcohol",
                    sortOrder: 10,
                    isRetired: false,
                    hydrationContributionRule: .alcohol(defaultABV: defaultABV)
                )
            ]
        )

        try catalogue.validate()
    }
    
    // GIVEN an alcohol rule with an out-of-range or non-finite ABV,
    // WHEN the catalogue is validated,
    // THEN validation rejects the ABV and identifies the drink.
    @Test(arguments: [
        -0.01,
        1.01,
        Double.infinity,
        -Double.infinity,
        Double.nan
    ])
    func catalogueRejectsInvalidDefaultABV(defaultABV: Double) {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "alcohol", name: "Alcohol", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "test-drink",
                    name: "Test drink",
                    categoryID: "alcohol",
                    sortOrder: 10,
                    isRetired: false,
                    hydrationContributionRule: .alcohol(defaultABV: defaultABV)
                )
            ]
        )

        let expectedError =
            DrinkCatalogue.ValidationError.invalidDefaultABV(
                drinkID: "test-drink"
            )

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
    
    // GIVEN a finite, nonnegative hydration ratio,
    // WHEN the catalogue is validated,
    // THEN validation accepts zero, fractions and values above one.
    @Test(arguments: [0.0, 0.75, 1.0, 1.25])
    func catalogueAcceptsValidHydrationRatio(ratio: Double) throws {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "water", name: "Water", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "test-drink", name: "Test drink", categoryID: "water",
                    sortOrder: 10, isRetired: false,
                    hydrationContributionRule: .ratio(ratio)
                )
            ]
        )

        try catalogue.validate()
    }

    // GIVEN a negative or non-finite hydration ratio,
    // WHEN the catalogue is validated,
    // THEN validation rejects the ratio and identifies the drink.
    @Test(arguments: [-0.01, Double.infinity, -Double.infinity, Double.nan])
    func catalogueRejectsInvalidHydrationRatio(ratio: Double) {
        let catalogue = DrinkCatalogue(
            schemaVersion: 1,
            version: "test-1",
            categories: [
                DrinkCategory(id: "water", name: "Water", sortOrder: 10)
            ],
            drinks: [
                DrinkDefinition(
                    id: "test-drink", name: "Test drink", categoryID: "water",
                    sortOrder: 10, isRetired: false,
                    hydrationContributionRule: .ratio(ratio)
                )
            ]
        )

        let expectedError =
            DrinkCatalogue.ValidationError.invalidHydrationRatio(
                drinkID: "test-drink"
            )

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
}
