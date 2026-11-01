//
//  AddDrinkDraft.swift
//  Watered
//
//  Created by Frank Sedivy on 03/09/2026.
//

import Foundation

/// The selected catalogue drink, amount and preparation before submission.
nonisolated struct AddDrinkDraft {
    let drinkID: String
    let volumeValue: Double
    let unit: LiquidUnit

    /// Nil selects the definition's current default preparation.
    var caffeineVariant: CaffeineVariant? = nil

    /// Nil selects the configured default, or no shots when they do not apply.
    var shotCount: Int? = nil

    /// Resolves current catalogue rules and creates a new entry with captured facts.
    ///
    /// - Parameters:
    ///   - resolver: The validated catalogue used for this submission.
    ///   - date: The date and time to log the new drink for.
    /// - Returns: A new entry with its own UUID and resolved snapshot.
    /// - Throws: A resolution or calculation error when the selection cannot be logged.
    func drinkEntry(
        using resolver: DrinkCatalogueSnapshotResolver,
        date: Date = Date()
    ) throws -> DrinkEntry {
        let amount = DrinkAmount(value: volumeValue, unit: unit)
        let snapshot = try resolver.resolve(
            drinkID: drinkID,
            amount: amount,
            caffeineVariant: caffeineVariant,
            shotCount: shotCount
        )

        return DrinkEntry(amount: amount, date: date, catalogueSnapshot: snapshot)
    }
}
