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
    }
    
    /// Checks the schema compatibility, unique IDs, category references and serving defaults.
    ///
    /// Supplied default volume must be positive and finite. Missing defaults are valid.
    ///
    /// - Throws: A 'ValidationError' identifying the first invalid catalogue value.
    ///
    func validate() throws {
        guard schemaVersion == 1 else {
            throw ValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        
        var categoryIDs = Set<String>()
        
        for category in categories {
            guard !categoryIDs.contains(category.id) else {
                throw ValidationError.duplicateCategoryID(category.id)
            }
            
            categoryIDs.insert(category.id)
        }
        
        var drinkIDs = Set<String>()
        
        for drink in drinks {
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


