//
//  CaffeineVariant.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// Identifies the caffeine preparation selected for a drink.
///
/// The drink definition determines which variants are available. Each has its own caffeine rule.
nonisolated enum CaffeineVariant: String, Codable, CaseIterable {
    /// The drink's regular preparation.
    case regular
    
    /// A decaffeinated preparation with a separately defined caffeine rule.
    ///
    /// Selecting decaf does not imply zero caffeine.
    case decaf

    /// A recipe without a caffeinated base; distinct from decaffeinated tea or coffee.
    case caffeineFree = "caffeine-free"

    /// Preparation text shared by saved details and recent-drink shortcuts.
    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .decaf: return "Decaf"
        case .caffeineFree: return "Caffeine-free"
        }
    }
}
