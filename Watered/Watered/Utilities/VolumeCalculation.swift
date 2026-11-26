//
//  VolumeCalculation.swift
//  Watered
//
//  Created by Frank Sedivy on 19/08/2026.
//

import Foundation

/// Centralises base-unit conversion for model arithmetic, independent of display formatting.
nonisolated enum VolumeCalculation {
    
    // MARK: - Base Unit
    
    /// The common unit for model arithmetic, independent of the user’s display unit.
    nonisolated static let baseUnit: UnitVolume = .milliliters
    
    // MARK: - Conversion
    
    /// Converts a volume to its value in the model’s base unit without rounding.
    nonisolated static func baseValue(from volume: Measurement<UnitVolume>) -> Double {
        volume.converted(to: baseUnit).value
    }
    
    // MARK: - Measurement Creation
    
    /// Wraps a value already expressed in the base unit as a volume measurement.
    nonisolated static func measurement(fromBaseValue value: Double) -> Measurement<UnitVolume> {
        Measurement(value: value, unit: baseUnit)
    }
}
