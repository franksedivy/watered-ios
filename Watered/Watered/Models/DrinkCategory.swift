//
//  DrinkCategory.swift
//  Watered
//
//  Created by Frank Sedivy on 07/10/2026.
//

import Foundation

/// A browsing category defined by the drink catalogue.
///
/// Categories organise the drink selection. They do not determine hydration contribution, caffeine content or HealthKit
/// export elegibility.
nonisolated struct DrinkCategory: Codable, Equatable, Identifiable {
    
    /// The stbal eidentifier, independent of the display name.
    let id: String
    
    /// The category name displayed in the drink picker
    let name: String
    
    /// The category's position relative to other categories.
    ///
    ///  Lower values appear first.
    let sortOrder: Int
}
