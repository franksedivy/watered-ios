//
//  DrinkDefinition.swift
//  Watered
//
//  Created by Frank Sedivy on 07/10/2026.
//

import Foundation

/// A drink available through the catalogue.
///
/// This describes a drink type, its optional serving defualt and hydration rule.
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
    
    /// The suggested serving volume in millilitres, when one is defined.
    ///
    /// This is a starting selection, not a restriction on the logged amount. A nil value means catalogue does not specify a
    /// default serving
    let defaultVolume: Double?
    
    /// The rule used to estimate hydration contribution when a drink is logged
    ///
    /// Catalogue JSON must provide this explicitly, including unknown rules.
    let hydrationContributionRule: HydrationContributionRule
    
    /// Creates a catalogue drink definition with serving and hydration information.
    ///
    /// - Parameters:
    ///   - id: The stable drink identifier.
    ///   - name: The display name.
    ///   - categoryID: The identifier of the containing category.
    ///   - sortOrder: the position within the category.
    ///   - isRetired: Whether the drink is unavailable for new selection.
    ///   - defaultVolume: The suggested serving volume if known (in milliliters).
    ///   - hydrationContributionRule: The contribution rule, defaulting to unknown.
    init(
        id: String,
        name: String,
        categoryID: String,
        sortOrder: Int,
        isRetired: Bool,
        defaultVolume: Double? = nil,
        hydrationContributionRule: HydrationContributionRule = .unknown
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.sortOrder = sortOrder
        self.isRetired = isRetired
        self.defaultVolume = defaultVolume
        self.hydrationContributionRule = hydrationContributionRule
    }
}
