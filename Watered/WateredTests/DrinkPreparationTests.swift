//
//  DrinkPreparationTests.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkPreparationTests {
    // GIVEN drink JSON with regular and decaf rules and a shot configuration,
    // WHEN the definition is decoded,
    // THEN its options, selected default and shot configuration are preserved.
    @Test func decodesCaffeineOptionsAndShotConfiguration() throws {
        let json = """
        {
            "id": "test-latte",
            "name": "Test latte",
            "categoryID": "coffee",
            "sortOrder": 10,
            "isRetired": false,
            "hydrationContributionRule": { "kind": "unknown" },
            "caffeineOptions": [
                {
                    "variant": "regular",
                    "rule": { "kind": "perShot", "amount": 60 }
                },
                {
                    "variant": "decaf",
                    "rule": { "kind": "perShot", "amount": 3 }
                }
            ],
            "defaultCaffeineVariant": "decaf",
            "shotConfiguration": {
                "supportedCounts": [1, 2],
                "defaultCount": 2
            }
        }
        """

        let drink = try JSONDecoder().decode(
            DrinkDefinition.self,
            from: Data(json.utf8)
        )

        #expect(drink.caffeineOptions == [
            CaffeineOption(variant: .regular, rule: .perShot(amount: 60)),
            CaffeineOption(variant: .decaf, rule: .perShot(amount: 3))
        ])
        #expect(drink.defaultCaffeineVariant == .decaf)
        #expect(drink.shotConfiguration == ShotConfiguration(
            supportedCounts: [1, 2],
            defaultCount: 2
        ))
    }
    
    // GIVEN two options representing the same caffeine variant,
    // WHEN the catalogue is validated,
    // THEN validation identifies the duplicated variant and drink.
    @Test(arguments: [CaffeineVariant.regular, CaffeineVariant.decaf])
    func rejectsDuplicateCaffeineVariants(variant: CaffeineVariant) {
        let drink = DrinkDefinition(
            id: "test-drink", name: "Test drink", categoryID: "coffee",
            sortOrder: 10, isRetired: false,
            caffeineOptions: [
                CaffeineOption(variant: variant, rule: .unknown),
                CaffeineOption(variant: variant, rule: .unknown)
            ],
            defaultCaffeineVariant: variant
        )
        let catalogue = DrinkCatalogue(
            schemaVersion: 1, version: "test-1",
            categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)],
            drinks: [drink]
        )
        let expectedError = DrinkCatalogue.ValidationError.duplicateCaffeineVariant(
            drinkID: "test-drink", variant: variant
        )

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }

    // GIVEN a decaf default with only regular available or no options,
    // WHEN the catalogue is validated,
    // THEN validation rejects the unavailable default.
    @Test(arguments: [[CaffeineVariant.regular], []])
    func rejectsUnavailableDefaultVariant(variants: [CaffeineVariant]) {
        let options = variants.map({ variant in
            return CaffeineOption(variant: variant, rule: .unknown)
        })
        let drink = DrinkDefinition(
            id: "test-drink", name: "Test drink", categoryID: "coffee",
            sortOrder: 10, isRetired: false,
            caffeineOptions: options, defaultCaffeineVariant: .decaf
        )
        let catalogue = DrinkCatalogue(
            schemaVersion: 1, version: "test-1",
            categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)],
            drinks: [drink]
        )
        let expectedError = DrinkCatalogue.ValidationError.unavailableDefaultCaffeineVariant(
            drinkID: "test-drink", variant: .decaf
        )

        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
    
    // GIVEN finite, nonnegative caffeine values in both numeric rule kinds,
    // WHEN the catalogue is validated,
    // THEN validation accepts zero and positive fractional values.
    @Test(arguments: [0.0, 12.5])
    func acceptsValidCaffeineValues(value: Double) throws {
        let drink = DrinkDefinition(
            id: "test-drink", name: "Test drink", categoryID: "coffee",
            sortOrder: 10, isRetired: false,
            caffeineOptions: [
                CaffeineOption(variant: .regular, rule: .perVolume(concentration: value)),
                CaffeineOption(variant: .decaf, rule: .perShot(amount: value))
            ],
            shotConfiguration: ShotConfiguration(supportedCounts: [1, 2], defaultCount: 1)
        )
        let catalogue = DrinkCatalogue(
            schemaVersion: 1, version: "test-1",
            categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)],
            drinks: [drink]
        )

        try catalogue.validate()
    }

    // GIVEN a non-default caffeine option with a negative or non-finite value,
    // WHEN the catalogue is validated,
    // THEN either numeric rule kind is rejected and the option is identified.
    @Test(arguments: [-0.01, Double.infinity, -Double.infinity, Double.nan])
    func rejectsInvalidCaffeineValues(value: Double) {
        let rules: [CaffeineRule] = [
            .perVolume(concentration: value),
            .perShot(amount: value)
        ]

        for rule in rules {
            let drink = DrinkDefinition(
                id: "test-drink", name: "Test drink", categoryID: "coffee",
                sortOrder: 10, isRetired: false,
                caffeineOptions: [
                    CaffeineOption(variant: .regular, rule: .unknown),
                    CaffeineOption(variant: .decaf, rule: rule)
                ],
                shotConfiguration: ShotConfiguration(supportedCounts: [1], defaultCount: 1)
            )
            let catalogue = DrinkCatalogue(
                schemaVersion: 1, version: "test-1",
                categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)],
                drinks: [drink]
            )
            let expectedError = DrinkCatalogue.ValidationError.invalidCaffeineValue(
                drinkID: "test-drink", variant: .decaf
            )

            #expect(throws: expectedError) {
                try catalogue.validate()
            }
        }
    }
    
    // GIVEN invalid shot choices or an unavailable default, when validated,
    // THEN the catalogue rejects the configuration and identifies the drink.
    @Test(arguments: [
        ShotConfiguration(supportedCounts: [], defaultCount: 1),
        ShotConfiguration(supportedCounts: [0, 1], defaultCount: 1),
        ShotConfiguration(supportedCounts: [-1, 1], defaultCount: 1),
        ShotConfiguration(supportedCounts: [1, 1], defaultCount: 1),
        ShotConfiguration(supportedCounts: [1, 2], defaultCount: 3)
    ])
    func rejectsInvalidShotConfiguration(configuration: ShotConfiguration) {
        let drink = DrinkDefinition(
            id: "test-drink", name: "Test drink", categoryID: "coffee",
            sortOrder: 10, isRetired: false,
            caffeineOptions: [
                CaffeineOption(variant: .regular, rule: .perShot(amount: 60))
            ],
            shotConfiguration: configuration
        )
        let catalogue = DrinkCatalogue(
            schemaVersion: 1, version: "test-1",
            categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)],
            drinks: [drink]
        )
        let expectedError = DrinkCatalogue.ValidationError.invalidShotConfiguration(
            drinkID: "test-drink"
        )
        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }

    // GIVEN a non-default per-shot option without shot configuration, when validated,
    // THEN the catalogue rejects it even though the default option needs no shots.
    @Test func rejectsMissingShotConfiguration() {
        let drink = DrinkDefinition(
            id: "test-drink", name: "Test drink", categoryID: "coffee",
            sortOrder: 10, isRetired: false,
            caffeineOptions: [
                CaffeineOption(variant: .regular, rule: .perVolume(concentration: 10)),
                CaffeineOption(variant: .decaf, rule: .perShot(amount: 3))
            ]
        )
        let catalogue = DrinkCatalogue(
            schemaVersion: 1, version: "test-1",
            categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)],
            drinks: [drink]
        )
        let expectedError = DrinkCatalogue.ValidationError.missingShotConfiguration(
            drinkID: "test-drink", variant: .decaf
        )
        #expect(throws: expectedError) {
            try catalogue.validate()
        }
    }
}
