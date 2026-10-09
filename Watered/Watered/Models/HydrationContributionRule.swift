//
//  HydrationContributionRule.swift
//  Watered
//
//  Created by Frank Sedivy on 09/10/2026.
//

import Foundation

/// Describes how to estimate a drink's hydration contribution.
///
/// Rules are indpenedent of browsing categories and display names. They do not determine quantities exported to HealthKit.
nonisolated enum HydrationContributionRule: Equatable, Codable {
    /// Applies a multiplier to the logged liquid volume.
    ///
    /// A value of 1 represents the full volume.
    case ratio(Double)
    
    /// Uses the alcohol contribution calculation with a defualt ABV.
    ///
    /// ABV is expressed as a fraction: 0.05 represents 5%
    case alcohol(defaultABV: Double)
    
    /// Indicates that no supported contribution estimate is avialable.
    ///
    /// Uknown must not be interepreted as zero contribution.
    case unknown
    
    // MARK: - Decoding
    
    private enum CodingKeys: String, CodingKey {
        case kind
        case ratio
        case defaultABV
    }
    
    private enum RuleKind: String, Codable {
        case ratio
        case alcohol
        case unknown
    }
    
    /// Decodes a contribution rule using its explicit kind and required values.
    ///
    /// - Parameter decoder: The decode supplying the rule data.
    /// - Throws: A decoding error for an unsupported kind, missing required field or incorrectly types value.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(RuleKind.self, forKey: .kind)
        
        switch kind {
        case .ratio:
            let ratio = try container.decode(Double.self, forKey: .ratio)
            self = .ratio(ratio)
            
        case .alcohol:
            let defaultABV = try container.decode(
                Double.self,
                forKey: .defaultABV
            )
            self = .alcohol(defaultABV: defaultABV)
            
        case .unknown:
            self = .unknown
        }
    }
    
    // MARK: - Encoding
    
    /// Encodes a contribution rule using its explicit kind and associated value.
    ///
    /// Unknown rules contain only the kind field.
    ///
    /// - Parameter encoder: The encoder receiving the rule data.
    /// - Throws: An encoding error if the encoder cannot represent a value.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .ratio(let ratio):
            try container.encode(RuleKind.ratio, forKey: .kind)
            try container.encode(ratio, forKey: .ratio)
            
        case .alcohol(let defualtABV):
            try container.encode(RuleKind.alcohol, forKey: .kind)
            try container.encode(defualtABV, forKey: .defaultABV)
            
        case .unknown:
            try container.encode(RuleKind.unknown, forKey: .kind)
        }
    }
}
