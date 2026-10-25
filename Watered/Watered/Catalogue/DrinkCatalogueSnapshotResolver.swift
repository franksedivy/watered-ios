//
//  DrinkCatalogueSnapshotResolver.swift
//  Watered
//
//  Created by Frank Sedivy on 24/10/2026.
//

import Foundation

/// Captures catalogue facts and resolved estimates for a new logged drink.
nonisolated struct DrinkCatalogueSnapshotResolver {
    enum ResolutionError: Error {
        case unavailableDrink(String)
        case unavailablePreparation(String)
        case unavailableShotCount(String)
    }
    
    /// Identifies the calculation logic sed to produce saved estimates.
    static let calculationVersion = "1"
    
    private let catalogue: DrinkCatalogue
    
    /// Creates a resolver after validation its catalogue
    ///
    /// - Parameter catalogue: The definitions to use for new logs.
    /// - Throws: A catalogue validation error when its content is invalid.
    init(catalogue: DrinkCatalogue) throws {
        try catalogue.validate()
        self.catalogue = catalogue
    }
    
    /// Resolves an active drink using its the selected preparation and shot count.
    ///
    /// - Parameters:
    ///  - drinkID: The stable catalogue identifier.
    ///  - amount: The consumed liquid amount.
    ///  - caffeineVariant: The selected preparation, or nil to use the drink's default
    ///  - shotCount: A supported count, or nil to use the configured default when appicable.
    /// - Returns: Identity, preparation, estimates and versions captured together.
    /// - Throws: A resolution or calculation error when the drink cannot be logged.
    func resolve(
        drinkID: String,
        amount: DrinkAmount,
        caffeineVariant: CaffeineVariant? = nil,
        shotCount: Int? = nil
    ) throws -> DrinkCatalogueSnapshot {
        guard let definition = catalogue.drink(withID: drinkID),
              !definition.isRetired else {
            throw ResolutionError.unavailableDrink(drinkID)
        }
        
        let variant = caffeineVariant ?? definition.defaultCaffeineVariant
        
        guard let option = definition.caffeineOptions.first(where: { option in
            return option.variant == variant
        }) else {
            throw ResolutionError.unavailablePreparation(drinkID)
        }
        
        let resolvedShotCount: Int?
        
        if let configuration = definition.shotConfiguration {
            let count = shotCount ?? configuration.defaultCount
            
            guard configuration.supportedCounts.contains(count) else {
                throw ResolutionError.unavailableShotCount(drinkID)
            }
            
            resolvedShotCount = count
        } else {
            guard shotCount == nil else {
                throw ResolutionError.unavailableShotCount(drinkID)
            }
            
            resolvedShotCount = nil
        }
            
        let hydration = try DrinkEstimateCalculator.hydrationContribution(
            for: amount,
            rule: definition.hydrationContributionRule
        )
        let caffeine = try DrinkEstimateCalculator.caffeineAmount(
            for: amount,
            rule: option.rule,
            shotCount: resolvedShotCount
        )
        
        return DrinkCatalogueSnapshot(
            drinkID: definition.id,
            drinkName: definition.name,
            caffeineVariant: variant,
            shotCount: resolvedShotCount,
            hydrationContribution: hydration,
            caffeineAmount: caffeine,
            catalogueVersion: catalogue.version,
            calculationVersion: Self.calculationVersion
        )
    }
}
