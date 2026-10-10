//
//  DrinkType.swift
//  Watered
//
//  Created by Frank Sedivy on 30/06/2026.
//

import Foundation

nonisolated enum DrinkType: String, CaseIterable {
    // MARK: - Cases

    // Non-alcoholic drinks
    case water  = "Water"
    case coffee = "Coffee"
    case tea    = "Tea"
    case juice  = "Juice"

    // Alcoholic drinks
    case beer   = "Beer"
    case cider  = "Cider"
    case wine   = "Wine"
    case spirits = "Spirits"

    // Other types
    case other  = "Other"

    // MARK: - Persistence
    //
    // Purpose:
    // Provides a stable value for persistence.
    //
    // Notes:
    // This is intentionally separate from rawValue because rawValue is currently
    // used as display text in the UI.
    var persistenceIdentifier: String {
        switch self {
        case .water:    return "water"
        case .coffee:   return "coffee"
        case .tea:      return "tea"
        case .juice:    return "juice"
        case .beer:     return "beer"
        case .cider:    return "cider"
        case .wine:     return "wine"
        case .spirits:  return "spirits"
        case .other:    return "other"
        }
    }

    // Purpose:
    // Recreates a drink type from a stored persistence value.
    init?(persistenceIdentifier: String) {
        switch persistenceIdentifier {
        case "water":    self = .water
        case "coffee":   self = .coffee
        case "tea":      self = .tea
        case "juice":    self = .juice
        case "beer":     self = .beer
        case "cider":    self = .cider
        case "wine":     self = .wine
        case "spirits":  self = .spirits
        case "other":    self = .other
        default:         return nil
        }
    }

    // MARK: - Hydration Contribution

    // Purpose:
    // Describes how Watered should estimate hydration contribution for this drink type.
    //
    // Returns:
    // A HydrationContributionRule.
    //
    // Behavior:
    // Non-alcoholic drinks use a simple ratio.
    // Alcoholic drinks use a default ABV for alcohol impact calculations.
    // Other remains unknown so Watered does not silently guess.
    var hydrationContributionRule: HydrationContributionRule {
        switch self {
        case .water:    return .ratio(1.0)
        case .coffee:   return .ratio(0.99)
        case .tea:      return .ratio(0.99)
        case .juice:    return .ratio(0.89)

        case .beer:     return .alcohol(defaultABV: 0.05)
        case .cider:    return .alcohol(defaultABV: 0.05)
        case .wine:     return .alcohol(defaultABV: 0.13)
        case .spirits:  return .alcohol(defaultABV: 0.40)

        case .other:    return .unknown
        }
    }
}
