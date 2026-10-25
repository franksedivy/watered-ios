//
//  DrinkCatalogueSnapshotResolverTests.swift
//  Watered
//
//  Created by Frank Sedivy on 24/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkCatalogueSnapshotResolverTests {
    // GIVEN the bundled latte definition and a consumed amount of 250 ml,
    // WHEN the resolver creates a snapshot using its default preparation,
    // THEN it captures identity, estimates, preparation and version information.
    @Test func resolverCapturesCatalogueFactsAndEstimates() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(
            catalogue: catalogue
        )

        let snapshot = try resolver.resolve(
            drinkID: "latte",
            amount: DrinkAmount(value: 250, unit: .milliliters)
        )

        #expect(snapshot.drinkID == "latte")
        #expect(snapshot.drinkName == "Latte")
        #expect(snapshot.caffeineVariant == .regular)
        #expect(snapshot.shotCount == nil)
        #expect(snapshot.caffeineAmount == nil)

        let contribution = try #require(snapshot.hydrationContribution)

        #expect(abs(contribution - 226.5) < 0.000001)
        #expect(snapshot.catalogueVersion == catalogue.version)
        #expect(
            snapshot.calculationVersion ==
                DrinkCatalogueSnapshotResolver.calculationVersion
        )
    }
    
    // GIVEN a coffee supporting regular, decaf and single or double shots,
    // WHEN defaults and an explicit double-shot decaf preparation are resolved,
    // THEN each snapshot captures the correct preparation and caffeine estimate, while hydration
    // contribution stays the same for the same consumed volume.
    @Test func resolverUsesSelectedPreparationAndShotCount() throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: makeCoffeeCatalogue())
        let amount = DrinkAmount(value: 250, unit: .milliliters)

        let defaultSnapshot = try resolver.resolve(
            drinkID: "test-coffee",
            amount: amount
        )
        let selectedSnapshot = try resolver.resolve(
            drinkID: "test-coffee",
            amount: amount,
            caffeineVariant: .decaf,
            shotCount: 2
        )

        #expect(defaultSnapshot.caffeineVariant == .regular)
        #expect(defaultSnapshot.shotCount == 1)
        #expect(defaultSnapshot.caffeineAmount == 60)
        #expect(selectedSnapshot.caffeineVariant == .decaf)
        #expect(selectedSnapshot.shotCount == 2)
        #expect(selectedSnapshot.caffeineAmount == 10)
        #expect(defaultSnapshot.hydrationContribution == 250)
        #expect(selectedSnapshot.hydrationContribution == 250)
    }
    
    // GIVEN a catalogue containing a retired coffee and an identifier absent from it,
    // WHEN either drink is requested for a new log,
    // THEN snapshot resolution fails.
    @Test(arguments: ["missing-coffee", "test-coffee"])
    func resolverRejectsMissingOrRetiredDrinks(drinkID: String) throws {
        let catalogue = makeCoffeeCatalogue(isRetired: true)
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)

        #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
            _ = try resolver.resolve(
                drinkID: drinkID,
                amount: DrinkAmount(value: 250, unit: .milliliters)
            )
        }
    }

    // GIVEN a coffee supporting only one or two shots,
    // WHEN a negative, zero or unsupported shot count is selected,
    // THEN snapshot resolution fails.
    @Test(arguments: [-1, 0, 3])
    func resolverRejectsUnsupportedShotCounts(shotCount: Int) throws {
        let resolver = try DrinkCatalogueSnapshotResolver(
            catalogue: makeCoffeeCatalogue()
        )

        #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
            _ = try resolver.resolve(
                drinkID: "test-coffee",
                amount: DrinkAmount(value: 250, unit: .milliliters),
                shotCount: shotCount
            )
        }
    }
}

// MARK: - Helpers
private func makeCoffeeCatalogue(isRetired: Bool = false) -> DrinkCatalogue {
    let definition = DrinkDefinition(
        id: "test-coffee",
        name: "Test coffee",
        categoryID: "coffee",
        sortOrder: 10,
        isRetired: isRetired,
        hydrationContributionRule: .ratio(1),
        caffeineOptions: [
            CaffeineOption(variant: .regular, rule: .perShot(amount: 60)),
            CaffeineOption(variant: .decaf, rule: .perShot(amount: 5))
        ],
        defaultCaffeineVariant: .regular,
        shotConfiguration: ShotConfiguration(supportedCounts: [1, 2], defaultCount: 1)
    )

    return DrinkCatalogue(
        schemaVersion: 1,
        version: "test-1",
        categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 10)],
        drinks: [definition]
    )
}
