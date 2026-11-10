//
//  DrinkCatalogue.swift
//  Watered
//
//  Created by Frank Sedivy on 07/10/2026.
//

import Foundation

/// A versioned collection of drink categories and definitions.
///
/// The loader assembles this model from a manifest and category definition files.
/// Decoding alone does not establish that the contents are valid.
nonisolated struct DrinkCatalogue: Codable, Equatable {
    /// The catalogue data schema understood by the app, independent of manifest packaging.
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
    
    init(schemaVersion: Int, version: String, categories: [DrinkCategory], drinks: [DrinkDefinition]) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.categories = categories
        self.drinks = drinks
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, version, categories, drinks }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        version = try container.decode(String.self, forKey: .version)
        categories = try container.decode([DrinkCategory].self, forKey: .categories)
        var definitions = try container.nestedUnkeyedContainer(forKey: .drinks)
        var decoded: [DrinkDefinition] = []
        while !definitions.isAtEnd {
            decoded.append(try DrinkDefinition(from: definitions.superDecoder(), requiresContent: schemaVersion >= 3, requiresWaterContent: schemaVersion >= 5))
        }
        drinks = decoded
    }

    // MARK: - Validation
    
    /// A reason the app cannot use a decoded catalogue.
    nonisolated enum ValidationError: Error, Equatable {
        case unsupportedSchemaVersion(Int)
        case duplicateCategoryID(String)
        case duplicateDrinkID(String)
        case unknownCategoryID(drinkID: String, categoryID: String)
        case invalidAlcoholConfiguration(drinkID: String)
        case invalidDefaultVolume(drinkID: String)
        case invalidHydrationRatio(drinkID: String)
        case invalidWaterContent(drinkID: String)
        case invalidDefaultABV(drinkID: String)
        case inconsistentAlcoholContent(drinkID: String)
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
    /// Shot configurations require nonempty, unique counts and an available default.
    /// Schema 1 requires positive counts; schemas 2 and 3 also permit zero.
    /// Category and drink IDs must be nonempty and contain no whitespace.
    ///
    /// - Throws: A 'ValidationError' identifying the first invalid catalogue value.
    ///
    func validate() throws {
        guard (1...6).contains(schemaVersion) else {
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
            
            if case .fraction(let value) = drink.waterContent,
               !value.isFinite || !(0...1).contains(value) {
                throw ValidationError.invalidWaterContent(drinkID: drink.id)
            }

            if case .alcoholOptions(let options, let nonAlcoholic) = drink.waterContent {
                guard schemaVersion >= 6, let configuration = drink.alcohol.configuration,
                      options.map(\.abv) == configuration.supportedABVs,
                      options.allSatisfy({ $0.fraction.isFinite && (0...1).contains($0.fraction) }),
                      (nonAlcoholic != nil) == (configuration.nonAlcoholic != nil),
                      nonAlcoholic.map({ $0.isFinite && (0...1).contains($0) }) ?? true else {
                    throw ValidationError.invalidWaterContent(drinkID: drink.id)
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
            
            if case .abv(let value) = drink.alcohol {
                guard value.isFinite, (0...1).contains(value) else {
                    throw ValidationError.invalidDefaultABV(drinkID: drink.id)
                }
            }
            if case .alcohol(let value) = drink.hydrationContributionRule {
                guard drink.alcohol == .abv(value) else {
                    throw ValidationError.inconsistentAlcoholContent(drinkID: drink.id)
                }
            }

            if let configuration = drink.alcohol.configuration {
                let steps = configuration.supportedABVs
                guard schemaVersion >= 4,
                      steps.count >= 2,
                      steps.allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 1 }),
                      steps == steps.sorted(), Set(steps).count == steps.count,
                      steps.contains(configuration.defaultABV),
                      drink.hydrationContributionRule == .ratio(0) else {
                    throw ValidationError.invalidAlcoholConfiguration(drinkID: drink.id)
                }
                if let preparation = configuration.nonAlcoholic {
                    guard preparation.hydrationRatio.isFinite, (0...1).contains(preparation.hydrationRatio),
                          preparation.maximumABV.isFinite, (0...1).contains(preparation.maximumABV),
                          preparation.maximumABV < steps[0] else {
                        throw ValidationError.invalidAlcoholConfiguration(drinkID: drink.id)
                    }
                }
            }

            var caffeineVariants = Set<CaffeineVariant>()
            
            for option in drink.caffeineOptions {
                guard !caffeineVariants.contains(option.variant) else {
                    throw ValidationError.duplicateCaffeineVariant(
                        drinkID: drink.id,
                        variant:option.variant
                    )
                }
                
                // Caffeine-free means known zero, never an unknown or positive estimate.
                if option.variant == .caffeineFree,
                   option.rule != .perVolume(concentration: 0) {
                    throw ValidationError.invalidCaffeineValue(drinkID: drink.id, variant: option.variant)
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
                if schemaVersion >= 3 {
                    guard drink.caffeineOptions.contains(where: {
                        if case .perShot = $0.rule { return true }
                        return false
                    }) else {
                        throw ValidationError.invalidShotConfiguration(drinkID: drink.id)
                    }
                }
                let counts = configuration.supportedCounts
                let containsOnlyNonnegativeCounts = counts.allSatisfy({ count in
                    return count >= (schemaVersion == 1 ? 1 : 0)
                })
                
                guard !counts.isEmpty,
                      containsOnlyNonnegativeCounts,
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


