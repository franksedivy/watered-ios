//
//  SnapshotFormatter.swift
//  Watered
//
//  Created by Frank Sedivy on 04/07/2026.
//
import Foundation

// Formats progress value for console output and early UI labels
nonisolated struct ProgressFormatter {
    nonisolated init() {}
    
    nonisolated func percentageString(from progress: Double) -> String {
        let roundedPercentage = Int((progress * 100).rounded())
        return "\(roundedPercentage)%"
    }
    /// Formats contribution percentages downwards to at most one decimal without changing saved values.
    nonisolated func contributionPercentageString(from ratio: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .floor
        return formatter.string(from: NSNumber(value: ratio)) ?? "Unknown"
    }
}
