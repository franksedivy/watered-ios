//
//  LiquidUnit.swift
//  Watered
//
//  Created by Frank Sedivy on 26/06/2026.
//

import Foundation

/// Supported logging and display units, with separate durable storage identifiers.
nonisolated enum LiquidUnit: String, CaseIterable, Identifiable {
    case milliliters = "ml"
    case usFluidOunces = "US fl oz"
    case imperialFluidOunces = "imp fl oz"

    /// Uses the unit itself as its stable identity in collections and pickers.
    var id: LiquidUnit {
        return self
    }

    // MARK: - Persistence
    /// The durable storage identifier, independent of the display label.
    var persistenceIdentifier: String {
        switch self {
        case .milliliters:          return "milliliters"
        case .usFluidOunces:        return "usFluidOunces"
        case .imperialFluidOunces:  return "imperialFluidOunces"
        }
    }

    /// Restores a unit from its durable identifier; unrecognised identifiers return nil.
    init?(persistenceIdentifier: String) {
        switch persistenceIdentifier {
        case "milliliters":          self = .milliliters
        case "usFluidOunces":        self = .usFluidOunces
        case "imperialFluidOunces":  self = .imperialFluidOunces
        default:                     return nil
        }
    }

    /// The Foundation unit used for conversions without changing the recorded amount.
    var foundationUnit: UnitVolume {
        switch self {
        case .milliliters:
            return .milliliters
        case .usFluidOunces:
            return .fluidOunces
        case .imperialFluidOunces:
            return .imperialFluidOunces
        }
    }
}
