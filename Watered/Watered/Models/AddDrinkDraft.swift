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

    /// Requests the definition's optional non-alcoholic preparation, not a known-zero ABV.
    /// Resolution requires support for that preparation and a nil `alcoholABV`.
    var isNonAlcoholic: Bool = false

    /// Selected exact ABV as a fraction (0.05 means 5%), for configurable alcoholic preparations.
    /// Nil uses their current configured default. Non-alcoholic preparations and definitions
    /// without alcohol choices require nil; resolution determines the captured facts.
    var alcoholABV: Double? = nil

    /// Resolves current catalogue rules and creates a new entry with captured facts.
    /// Non-alcoholic choices capture the configured upper bound with unknown exact ABV;
    /// unsupported or contradictory alcohol selections fail resolution rather than being coerced.
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
            shotCount: shotCount,
            isNonAlcoholic: isNonAlcoholic,
            alcoholABV: alcoholABV
        )

        return DrinkEntry(amount: amount, date: date, catalogueSnapshot: snapshot)
    }
}
