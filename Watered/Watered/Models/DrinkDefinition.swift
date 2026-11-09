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
    
    /// Explicit caffeine content; only configurable drinks carry options.
    let caffeine: CaffeineContent

    /// Alcohol content, independent of the chosen hydration policy.
    let alcohol: AlcoholContent

    /// Derived adapters preserve the existing preparation and saved-snapshot contract.
    var caffeineOptions: [CaffeineOption] { caffeine.options }
    var defaultCaffeineVariant: CaffeineVariant { caffeine.defaultVariant }

    /// The supported shot counts and their default, when applicable.
    ///
    /// A nil value means the drink has no shot-count configuration.
    let shotConfiguration: ShotConfiguration?
    
    /// Creates a definition from the legacy preparation API; new catalogue content uses explicit content objects.
    ///
    /// - Parameters:
    ///   - id: The stable drink identifier.
    ///   - name: The display name.
    ///   - categoryID: The identifier of the containing category.
    ///   - sortOrder: the position within the category.
    ///   - isRetired: Whether the drink is unavailable for new selection.
    ///   - defaultVolume: The suggested serving volume if known (in milliliters).
    ///   - hydrationContributionRule: The contribution rule, defaulting to unknown.
    ///   - caffeineOptions: Available preparations, defaulting to regular with an unknown rule.
    ///   - defaultCaffeineVariant: The initial preparration, defaulting to regular.
    ///   - shotConfiguration: Available shot counts and their defualt, if applicable.
    init(
        id: String,
        name: String,
        categoryID: String,
        sortOrder: Int,
        isRetired: Bool,
        defaultVolume: Double? = nil,
        hydrationContributionRule: HydrationContributionRule = .unknown,
        caffeineOptions: [CaffeineOption] = [
            CaffeineOption(variant: .regular, rule: .unknown)
        ],
        defaultCaffeineVariant: CaffeineVariant = .regular,
        shotConfiguration: ShotConfiguration? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.sortOrder = sortOrder
        self.isRetired = isRetired
        self.defaultVolume = defaultVolume
        self.hydrationContributionRule = hydrationContributionRule
        self.caffeine = .options(defaultVariant: defaultCaffeineVariant, options: caffeineOptions)
        if case .alcohol(let value) = hydrationContributionRule {
            self.alcohol = .abv(value)
        } else {
            self.alcohol = .unknown
        }
        self.shotConfiguration = shotConfiguration
    }

    /// Creates a definition using explicit content, with no duplicate caffeine configuration.
    init(
        id: String, name: String, categoryID: String, sortOrder: Int, isRetired: Bool,
        defaultVolume: Double? = nil, hydrationContributionRule: HydrationContributionRule = .unknown,
        caffeine: CaffeineContent, alcohol: AlcoholContent,
        shotConfiguration: ShotConfiguration? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.sortOrder = sortOrder
        self.isRetired = isRetired
        self.defaultVolume = defaultVolume
        self.hydrationContributionRule = hydrationContributionRule
        self.caffeine = caffeine
        self.alcohol = alcohol
        self.shotConfiguration = shotConfiguration
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, categoryID, sortOrder, isRetired, defaultVolume, hydrationContributionRule
        case caffeine, alcohol, shotConfiguration, caffeineOptions, defaultCaffeineVariant
    }
    private enum HydrationKeys: String, CodingKey { case kind }

    init(from decoder: any Decoder) throws {
        try self.init(from: decoder, requiresContent: (decoder.userInfo[.catalogueSchemaVersion] as? Int ?? 0) >= 3)
    }

    /// Schema 3 requires both content objects. Legacy catalogue decoding never touches saved entries.
    init(from decoder: any Decoder, requiresContent: Bool) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modern = requiresContent || container.contains(.caffeine) || container.contains(.alcohol)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        categoryID = try container.decode(String.self, forKey: .categoryID)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        isRetired = try container.decode(Bool.self, forKey: .isRetired)
        defaultVolume = try container.decodeIfPresent(Double.self, forKey: .defaultVolume)
        shotConfiguration = try container.decodeIfPresent(ShotConfiguration.self, forKey: .shotConfiguration)

        if modern {
            try CatalogueObjectKeys.require(decoder, allowed: [
                "id", "name", "categoryID", "sortOrder", "isRetired", "defaultVolume",
                "hydrationContributionRule", "caffeine", "alcohol", "shotConfiguration"
            ])
            caffeine = try container.decode(CaffeineContent.self, forKey: .caffeine)
            alcohol = try container.decode(AlcoholContent.self, forKey: .alcohol)
            let hydrationDecoder = try container.superDecoder(forKey: .hydrationContributionRule)
            let hydration = try hydrationDecoder.container(keyedBy: HydrationKeys.self)
            let kind = try hydration.decode(String.self, forKey: .kind)
            if kind == "alcohol" {
                try CatalogueObjectKeys.require(hydrationDecoder, allowed: ["kind"])
                guard case .abv(let value) = alcohol else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .alcohol, in: container, debugDescription: "Alcohol hydration requires a known ABV."
                    )
                }
                hydrationContributionRule = .alcohol(defaultABV: value)
            } else {
                try CatalogueObjectKeys.require(hydrationDecoder, allowed: kind == "ratio" ? ["kind", "ratio"] : ["kind"])
                hydrationContributionRule = try HydrationContributionRule(from: hydrationDecoder)
            }
        } else {
            caffeine = .options(
                defaultVariant: try container.decode(CaffeineVariant.self, forKey: .defaultCaffeineVariant),
                options: try container.decode([CaffeineOption].self, forKey: .caffeineOptions)
            )
            hydrationContributionRule = try container.decode(HydrationContributionRule.self, forKey: .hydrationContributionRule)
            if case .alcohol(let value) = hydrationContributionRule {
                alcohol = .abv(value)
            } else {
                alcohol = .unknown
            }
        }
    }

    /// Writes the compact content structure. ABV is authored once, under alcohol.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(isRetired, forKey: .isRetired)
        try container.encodeIfPresent(defaultVolume, forKey: .defaultVolume)
        try container.encode(caffeine, forKey: .caffeine)
        try container.encode(alcohol, forKey: .alcohol)
        try container.encodeIfPresent(shotConfiguration, forKey: .shotConfiguration)
        if case .alcohol = hydrationContributionRule {
            var hydration = container.nestedContainer(keyedBy: HydrationKeys.self, forKey: .hydrationContributionRule)
            try hydration.encode("alcohol", forKey: .kind)
        } else {
            try container.encode(hydrationContributionRule, forKey: .hydrationContributionRule)
        }
    }

}


extension CodingUserInfoKey {
    nonisolated static let catalogueSchemaVersion = CodingUserInfoKey(rawValue: "catalogueSchemaVersion")!
}
