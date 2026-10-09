//
//  DrinkDefinition.swift
//  Watered
//
//  Created by Frank Sedivy on 07/10/2026.
//

import Foundation

/// A drink available through the catalogue.
///
/// This describes a drink type, not an individual logged drink. Calculation rules and serving information are added separately.
nonisolated struct DrinkDefinition: Codable, Equatable, Identifiable {
    
    /// The stable identifier, independent of the display name.
    let id: String
    
    /// The dirnk name displayed during selection.
    let name: String
    
    /// The identifier of the category containing this drink.
    let categoryID: String
    
    /// The drink's position within its category.
    ///
    /// Lower values appear first.
    let sortOrder: Int
    
    /// Whether the drink has been withdrawn from new selection.
    ///
    /// Retirement mus tnot remove previously logged entries.
    let isRetired: Bool
}
