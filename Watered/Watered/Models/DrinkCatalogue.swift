//
//  DrinkCatalogue.swift
//  Watered
//
//  Created by Frank Sedivy on 07/10/2026.
//

import Foundation

/// A versioned collection of drink categories and definitions.
///
/// This represents the contets of a catalogue JSON file. Decoding alone does not establish that its content are valid.
nonisolated struct DrinkCatalogue: Codable, Equatable {
    /// The JSON format version understood by the app.
    ///
    /// Changes when the catalogue structure or interprestion changes.
    let schemaVersion: Int
    
    /// The identifier of this catalogue content release.
    ///
    /// Changes when definitions change, even if the JSON format stays the same.
    let version: String
    
    /// The categories used to organise drink selection
    let categories: [DrinkCategory]
    
    /// The drink definitions, including any retained retired definitions
    let drinks: [DrinkDefinition]
    
    // MARK: - Validation
    
    /// A reason the app cannot use a decoded catalogue.
    nonisolated enum ValidationError: Error, Equatable {
        case unsupportedSchemaVersion(Int)
        case duplicateCategoryID(String)
        case duplicateDrinkID(String)
        case unknownCategoryID(drinkID: String, categoryID: String)
        case invalidDefaultVolume(drinkID: String)
        case invalidHydrationRatio(drinkID: String)
        case invalidDefaultABV(drinkID: String)
        case duplicateCaffeineVariant(drinkID: String, variant: CaffeineVariant)
        case unavailableDefaultCaffeineVariant(drinkID: String, variant: CaffeineVariant)
        case invalidCaffeineValue(drinkID: String, variant: CaffeineVariant)
        case missingShotConfiguration(drinkID: String, variant: CaffeineVariant)
        case invalidShotConfiguration(drinkID: String)
        case invalidCategoryID(String)
        case invalidDrinkID(String)
    }
    
    /// Checks catalogue structure, numeric rules and preparation consistency.
    ///
    /// Supplied default volume must be positive and finite.
    /// Missing defaults are valid. Hydration ratios must be finite and non negative, with no upper limit.
    /// Default ABV must be finite and between zero and one inclusive. Explicit unknown rules are valid without numeric values.
    /// Caffeine variants must be unique per drink and include the configured default
    /// Caffiene concentrations and per-shot amounts must be finite and nonnegative.
    /// Per-shot caffeine rules require a shot configuration.
    /// Shot configurations require nonempty, unique, positive counts and an avialable default
    /// Category and drink IDs must be nonempty and contain no whitespace.
    ///
    /// - Throws: A 'ValidationError' identifying the first invalid catalogue value.
    ///
    func validate() throws {
        guard schemaVersion == 1 else {
            throw ValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        
        var categoryIDs = Set<String>()
        
        for category in categories {
            let hasWhiteSpace = category.id.contains(where: { character in
                return character.isWhitespace
            })
            
            guard !category.id.isEmpty && !hasWhiteSpace else {
                throw ValidationError.invalidCategoryID(category.id)
            }
            
            guard !categoryIDs.contains(category.id) else {
                throw ValidationError.duplicateCategoryID(category.id)
            }
            
            categoryIDs.insert(category.id)
        }
        
        var drinkIDs = Set<String>()
        
        for drink in drinks {
            let hasWhitespace = drink.id.contains(where: {character in
                return character.isWhitespace
            })
            
            guard !drink.id.isEmpty && !hasWhitespace else {
                throw ValidationError.invalidDrinkID(drink.id)
            }
            
            guard !drinkIDs.contains(drink.id) else {
                throw ValidationError.duplicateDrinkID(drink.id)
            }
            
            guard categoryIDs.contains(drink.categoryID) else {
                throw ValidationError.unknownCategoryID(
                    drinkID: drink.id,
                    categoryID: drink.categoryID
                )
            }
            
            if let defaultVolume = drink.defaultVolume {
                guard defaultVolume.isFinite && defaultVolume > 0 else {
                    throw ValidationError.invalidDefaultVolume(
                        drinkID: drink.id
                    )
                }
            }
            
            switch drink.hydrationContributionRule {
            case .ratio(let ratio):
                guard ratio.isFinite && ratio >= 0 else {
                    throw ValidationError.invalidHydrationRatio(
                        drinkID: drink.id
                    )
                }
                
            case .alcohol(let defaultABV):
                guard defaultABV.isFinite &&
                        defaultABV >= 0 &&
                        defaultABV <= 1 else {
                    throw ValidationError.invalidDefaultABV(
                        drinkID: drink.id
                    )
                }
                
            case .unknown:
                break
            }
            
            var caffeineVariants = Set<CaffeineVariant>()
            
            for option in drink.caffeineOptions {
                guard !caffeineVariants.contains(option.variant) else {
                    throw ValidationError.duplicateCaffeineVariant(
                        drinkID: drink.id,
                        variant:option.variant
                    )
                }
                
                switch option.rule {
                case .perVolume(let concentration):
                    guard concentration.isFinite && concentration >= 0 else {
                        throw ValidationError.invalidCaffeineValue(
                            drinkID: drink.id,
                            variant: option.variant
                        )
                    }
                case .perShot(let amount):
                    guard amount.isFinite && amount >= 0 else {
                        throw ValidationError.invalidCaffeineValue(
                            drinkID: drink.id,
                            variant: option.variant
                        )
                    }
                    guard drink.shotConfiguration != nil else {
                        throw ValidationError.missingShotConfiguration(
                            drinkID: drink.id,
                            variant: option.variant
                        )
                    }
                case .unknown:
                    break
                }
                
                caffeineVariants.insert(option.variant)
            }
            
            guard caffeineVariants.contains(drink.defaultCaffeineVariant) else {
                throw ValidationError.unavailableDefaultCaffeineVariant(
                    drinkID: drink.id,
                    variant: drink.defaultCaffeineVariant
                )
            }
            
            if let configuration = drink.shotConfiguration {
                let counts = configuration.supportedCounts
                let containsOnlyPositiveCounts = counts.allSatisfy({ count in
                    return count > 0
                })
                
                guard !counts.isEmpty,
                      containsOnlyPositiveCounts,
                      Set(counts).count == counts.count,
                      counts.contains(configuration.defaultCount) else {
                    throw ValidationError.invalidShotConfiguration(
                        drinkID: drink.id
                    )
                }
            }
            
            drinkIDs.insert(drink.id)
        }
    }
    
    // MARK: - Lookup
    
    /// Finds an active or retired drink definition by its stable identifier.
    ///
    /// - Parameter id: The catalogue identifier to find.
    /// - Returns: The matching definition, or 'nil' when the identifier is unknown.
    /// - Precondition: The catalogue has passed validation.
    func drink(withID id: String) -> DrinkDefinition? {
        return drinks.first(where: { drink in
            return drink.id == id
        })
    }
    
    // MARK: - Selection
    
    /// All catalogue categories, ordered by their configured positoin.
    ///
    /// Categories with equal sort positions are ordered by their stable IDs.
    /// This orders categories without filtering out those with no active drinks.
    ///
    /// - Precondition: The catalogue has passed validation.
    var orderedCategories: [DrinkCategory] {
        return categories.sorted(by: {first, second in
            if first.sortOrder == second.sortOrder {
                return first.id < second.id
            }
            
            return first.sortOrder < second.sortOrder
        })
    }
    
    /// Returns active drinks in a category, ordered for selection.
    ///
    /// Drinks with equal sort positions are ordered by their stable IDs
    ///
    /// - Parameter categoryID: The category identifier to select form.
    /// - Returns: Ordered active definitions, or an empty array if none match.
    /// - Precondition: The catalogue has passed validation.
    func activeDrinks(inCategoryID categoryID: String) -> [DrinkDefinition] {
        let matchingDrinks = drinks.filter({ drink in
            return drink.categoryID == categoryID && !drink.isRetired
        })
        
        return matchingDrinks.sorted(by: {first, second in
            if first.sortOrder == second.sortOrder {
                return first.id < second.id
            }
            
            return first.sortOrder < second.sortOrder
        })
    }
}


