//
//  CaffeineVariant.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation

/// Indetifies the caffeine preparation selected for a drink.
///
/// The dirnk definition determines which variants are avialable. Each supported variant has its own caffeine estimateion rule.
nonisolated enum CaffeineVariant: String, Codable, CaseIterable {
    /// The drink's regular preparation.
    case regular
    
    /// A decaffeinated preparation with a separately defined caffeine rule.
    ///
    /// Selecting decaf does not imply zero caffeine.
    case decaf
}
