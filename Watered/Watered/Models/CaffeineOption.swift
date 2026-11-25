//
//  CaffeineOption.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// A caffeine preparation available for a particular drink.
///
/// Each option pairs a variant with its own estimation rule. Availability and estimated caffeine are separate: an available
/// option may have an explicitly unknown rule
nonisolated struct CaffeineOption: Codable, Equatable, Identifiable {
    /// The preparation represented by this option.
    let variant: CaffeineVariant
    
    /// The caffeine estimation rule for this preparation.
    let rule: CaffeineRule
    
    init(variant: CaffeineVariant, rule: CaffeineRule) {
        self.variant = variant
        self.rule = rule
    }

    private enum CodingKeys: String, CodingKey { case variant, rule }

    init(from decoder: any Decoder) throws {
        try CatalogueObjectKeys.require(decoder, allowed: ["variant", "rule"])
        let container = try decoder.container(keyedBy: CodingKeys.self)
        variant = try container.decode(CaffeineVariant.self, forKey: .variant)
        rule = try container.decode(CaffeineRule.self, forKey: .rule)
    }

    /// The option's identity within a single drink definition.
    ///
    /// A drink must not contain multiple options for the same variant.
    var id: CaffeineVariant {
        return variant
    }
}
