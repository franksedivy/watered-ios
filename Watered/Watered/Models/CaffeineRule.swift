//
//  CaffeineRules.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// Describes how to estimate caffeine for a prepared dirnk.
///
/// Numeric amounts are expressed in milligrams. These rules describe estimates, not measured caffeine content or
/// HealthKit export elibiligity.
nonisolated enum CaffeineRule: Equatable, Codable {
    /// Estimates caffeine from the finished drink's volume.
    ///
    /// Concrentration is expressed as milligrams per 100 millilitres.
    case perVolume(concentration: Double)
    
    /// Estimates caffeine from the selected number of espresso shots.
    ///
    /// Amount is expressed as milligrams per shot, indepenedent of this finished drink's total volume
    case perShot(amount: Double)
    
    /// Indicates that no supported caffeine estimate is avialable.
    ///
    /// Unknown is distinct from an explicitly known zero amount.
    case unknown
    
    // MARK: - Decoding
    
    private enum CodingKeys: String, CodingKey {
        case kind
        case concentration
        case amount
    }
    
    private enum RuleKind: String, Codable {
        case perVolume
        case perShot
        case unknown
    }
    
    /// Decodes a caffeine rule using its explicit kind and required value.
    ///
    /// concentration is in milligrams per 100 millilitres. Per-shot amounts are in milligrams per shot.
    ///
    /// - Parameter decoder: The decoder supplying the rule data.
    /// - Throws: A decoding error for an unsupported kind, missing required field or incorrectly typed value.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(RuleKind.self, forKey: .kind)
        
        switch kind {
        case .perVolume:
            let concentration = try container.decode(
                Double.self,
                forKey: .concentration
            )
            self = .perVolume(concentration: concentration)
            
        case .perShot:
            let amount = try container.decode(Double.self, forKey: .amount)
            self = .perShot(amount: amount)
            
        case .unknown:
            self = .unknown
        }
    }
    
    // MARK: - Encoding
    
    /// Encodes a caffeine rule using its explicit kind and associated value.
    ///
    /// Unknown rules contain only the kind field.
    ///
    /// - Parameter encoder: The encoder receiving the rule data.
    /// - Throws: An encoding error if the encoder cannot represent a value.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .perVolume(let concentration):
            try container.encode(RuleKind.perVolume, forKey: .kind)
            try container.encode(concentration, forKey: .concentration)
            
        case .perShot(let amount):
            try container.encode(RuleKind.perShot, forKey: .kind)
            try container.encode(amount, forKey: .amount)
            
        case .unknown:
            try container.encode(RuleKind.unknown, forKey: .kind)
        }
    }
}
