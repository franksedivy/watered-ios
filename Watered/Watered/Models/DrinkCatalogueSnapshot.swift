//
//  DrinkCatalogueSnapshot.swift
//  Watered
//
//  Created by Frank Sedivy on 24/10/2026.
//

import Foundation

/// Preserves catalogue identity, preparation and estimates for a logged drink
///
/// Values are captured when logging. Later catalogue changes must not alter them. The entry separately owns its amount,
/// timestamps and source.
nonisolated struct DrinkCatalogueSnapshot: Equatable {
    /// The stable catalogue identifier.
    let drinkID: String
    
    /// The name at logging time, retained if the definition becomes unavailable.
    let drinkName: String
    
    /// The caffeine preparation selected when logging.
    let caffeineVariant: CaffeineVariant
    
    /// The selected shot count, or nil when shot counts do not apply.
    let shotCount: Int?
    
    /// The resolved hydration contribution in millilitres.
    ///
    /// Nil means unknown. Negative values represent an estimated contribution.
    let hydrationContribution: Double?
    
    /// The resolved caffeine estimate in milligrams
    ///
    /// Nil means unknown. Zero means an explicitly known zero amount.
    let caffeineAmount: Double?
    
    /// The catalogue content version used when logging.
    let catalogueVersion: String
    
    /// The application calculation version used to resolve the estimates.
    ///
    /// This is independent of the catalogue's JSON schema version.
    let calculationVersion: String
}
