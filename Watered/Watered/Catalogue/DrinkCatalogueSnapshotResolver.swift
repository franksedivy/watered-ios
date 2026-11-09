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
        case unavailableAlcoholPreparation(String)
    }
    
    /// Identifies the calculation logic used to produce saved estimates.
    static let calculationVersion = "3"
    
    private let catalogue: DrinkCatalogue
    
    /// Creates a resolver after validating its catalogue.
    ///
    /// - Parameter catalogue: The definitions to use for new logs.
    /// - Throws: A catalogue validation error when its content is invalid.
    init(catalogue: DrinkCatalogue) throws {
        try catalogue.validate()
        self.catalogue = catalogue
    }
    
    /// Resolves an active drink using the selected preparation and shot count.
    ///
    /// - Parameters:
    ///   - drinkID: The stable catalogue identifier.
    ///   - amount: The consumed liquid amount.
    ///   - caffeineVariant: The selected preparation, or nil to use the drink's default.
    ///   - shotCount: A supported count, or nil to use the configured default when applicable.
    /// - Returns: Identity, preparation, estimates and versions captured together.
    /// - Throws: A resolution or calculation error when the drink cannot be logged.
    func resolve(
        drinkID: String,
        amount: DrinkAmount,
        caffeineVariant: CaffeineVariant? = nil,
        shotCount: Int? = nil,
        isNonAlcoholic: Bool = false,
        alcoholABV: Double? = nil
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
            
        var hydrationRule = definition.hydrationContributionRule
        var resolvedABV: Double?
        var upperBound: Double?
        var capturedNonAlcoholic: Bool?
        if let configuration = definition.alcohol.configuration {
            capturedNonAlcoholic = isNonAlcoholic
            if isNonAlcoholic {
                guard let preparation = configuration.nonAlcoholic, alcoholABV == nil else {
                    throw ResolutionError.unavailableAlcoholPreparation(drinkID)
                }
                hydrationRule = .ratio(preparation.hydrationRatio)
                upperBound = preparation.maximumABV
            } else {
                let value = alcoholABV ?? configuration.defaultABV
                guard configuration.supportedABVs.contains(value) else {
                    throw ResolutionError.unavailableAlcoholPreparation(drinkID)
                }
                resolvedABV = value
            }
        } else {
            guard !isNonAlcoholic, alcoholABV == nil else {
                throw ResolutionError.unavailableAlcoholPreparation(drinkID)
            }
            if case .abv(let value) = definition.alcohol { resolvedABV = value }
        }

        let hydration = try DrinkEstimateCalculator.hydrationContribution(
            for: amount,
            rule: hydrationRule
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
            calculationVersion: Self.calculationVersion,
            catalogueSchemaVersion: catalogue.schemaVersion,
            isNonAlcoholic: capturedNonAlcoholic,
            alcoholABV: resolvedABV,
            alcoholABVUpperBound: upperBound
        )
    }
}
