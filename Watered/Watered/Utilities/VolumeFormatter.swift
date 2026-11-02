//
//  VolumeFormatter.swift
//  Watered
//
//  Created by Frank Sedivy on 03/07/2026.
//

import Foundation

/// Converts volume measurements into localised display text without changing stored values.
nonisolated struct VolumeFormatter {
    private let locale: Locale

    /// Creates a formatter using the supplied locale for unit names and number formatting.
    ///
    /// - Parameter locale: The display locale; defaults to the current locale.
    init(locale: Locale = .current) {
        self.locale = locale
    }
    
    /// Formats a volume as a rounded whole number in the requested unit.
    ///
    /// - Parameters:
    ///   - volume: The original measurement, including its source unit.
    ///   - unit: The display unit; defaults to millilitres.
    /// - Returns: Localised volume text such as "1000 ml" or "34 US fl oz".
    func wholeNumberString(
        from volume: Measurement<UnitVolume>,
        displayedAs unit: LiquidUnit = .milliliters
    ) -> String {
        string(from: volume, displayedAs: unit, fractionLength: 0...0)
    }

    /// Formats a converted volume with configurable fractional precision.
    ///
    /// - Parameters:
    ///   - volume: The original measurement, including its source unit.
    ///   - unit: The display unit; defaults to millilitres.
    ///   - fractionLength: Allowed decimal places; defaults to zero through three.
    /// - Returns: Localised text that distinguishes US and imperial fluid ounces.
    func string(
        from volume: Measurement<UnitVolume>,
        displayedAs unit: LiquidUnit = .milliliters,
        fractionLength: ClosedRange<Int> = 0...3
    ) -> String {
        let convertedVolume = volume.converted(to: unit.foundationUnit)
        
        return convertedVolume.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle:
                    .number.precision(.fractionLength(fractionLength))
                    .grouping(.never)
            )
            .locale(locale)
        )
    }
}
