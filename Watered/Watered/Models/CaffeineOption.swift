//
//  CaffeineOption.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// A caffeine preparation available for a particular drink.
///
/// Each option pairs a variant with its own estimateion rule. Availability and estimated caffeine are separate: an available
/// option may have an explicitly unknown rule
nonisolated struct CaffeineOption: Codable, Equatable, Identifiable {
    /// The preparation represented by this option.
    let variant: CaffeineVariant
    
    /// The caffeine estimation rule for this prepapration.
    let rule: CaffeineRule
    
    /// The option's identitiy within a single drink definition.
    ///
    /// A drink mus tnot contain multiple options for the same variant.
    var id: CaffeineVariant {
        return variant
    }
}
