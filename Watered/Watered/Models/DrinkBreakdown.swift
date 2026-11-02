//
//  DrinkBreakdown.swift
//  Watered
//
//  Created by Frank Sedivy on 17/08/2026.
//

import Foundation

/// Grouped volumes for one logged drink identity.
nonisolated struct DrinkBreakdown {
    /// The identity used to group logged drinks.
    let drinkID: String

    /// The captured name shown for this group.
    let displayName: String

    /// The total raw liquid volume in this group.
    let totalVolume: Measurement<UnitVolume>

    /// The estimated hydration contribution, or nil if any entry is unknown.
    let totalHydrationVolume: Measurement<UnitVolume>?
}
