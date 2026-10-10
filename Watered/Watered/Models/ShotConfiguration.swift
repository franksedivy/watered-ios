//
//  ShotConfiguration.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// Defines the espresso shot counts available for a drink.
///
/// This configures preparation choices, not the user's current selection. Changing shot count does not itself change the
/// finished drink volume.
nonisolated struct ShotConfiguration: Codable, Equatable {
    /// The supported shot counts.
    ///
    /// Values must be positive and unique, and the collection must not be empty.
    let supportedCounts: [Int]
    
    /// The initially selected shot count.
    ///
    /// This must be included in supportedCounts.
    let defaultCount: Int
}
