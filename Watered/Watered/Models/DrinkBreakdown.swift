//
//  DrinkBreakdown.swift
//  Watered
//
//  Created by Frank Sedivy on 17/08/2026.
//

import Foundation

nonisolated struct DrinkBreakdown {
    /// The broad type retained while existing callers are converted
    let type: DrinkType
    
    /// The identity used to group logged drinks
    let drinkID: String
    
    /// The name shown for this group
    let displayName: String
    
    /// The raw liquid volume in this group
    let totalVolume: Measurement<UnitVolume>
    
    /// The estimated hydration contribution, or nil if any entry is unknown.
    let totalHydrationVolume: Measurement<UnitVolume>?
    
    /// Creates a breakdwon with captured indeitity when available
    ///
    /// - Parameters:
    ///  - drinkID: The catalogue ID, falling back to the legacy type ID.
    ///  - displayName: The captured name, falling back to the legacy type name
    init(
        type: DrinkType,
        totalVolume: Measurement<UnitVolume>,
        totalHydrationVolume: Measurement<UnitVolume>?,
        drinkID: String? = nil,
        displayName: String? = nil
    ) {
        self.type = type
        self.drinkID = drinkID ?? type.persistenceIdentifier
        self.displayName = displayName ?? type.rawValue
        self.totalVolume = totalVolume
        self.totalHydrationVolume = totalHydrationVolume
    }
}
