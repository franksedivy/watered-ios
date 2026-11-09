//
//  RecentDrinkOption.swift
//  Watered
//
//  Created by Frank Sedivy on 04/09/2026.
//

import Foundation

/// A currently available shortcut that creates a fresh catalogue-backed drink.
nonisolated struct RecentDrinkOption: Identifiable {
    /// Distinguishes amounts, units and preparations without relying on display text.
    nonisolated struct ID: Hashable {
        let drinkID: String
        let volumeValue: Double
        let unit: LiquidUnit
        let caffeineVariant: CaffeineVariant
        let shotCount: Int?
        let isNonAlcoholic: Bool
        let alcoholABV: Double?
    }

    let drinkID: String
    let drinkName: String
    let amount: DrinkAmount
    let caffeineVariant: CaffeineVariant
    let shotCount: Int?
    let isNonAlcoholic: Bool
    let alcoholABV: Double?

    /// Whether the current definition offers a choice of caffeine preparations.
    private let showsCaffeineVariant: Bool

    var id: ID {
        ID(
            drinkID: drinkID,
            volumeValue: amount.value,
            unit: amount.unit,
            caffeineVariant: caffeineVariant,
            shotCount: shotCount,
            isNonAlcoholic: isNonAlcoholic,
            alcoholABV: alcoholABV
        )
    }

    /// Creates a shortcut from a supported preparation and the current drink definition.
    ///
    /// - Parameters:
    ///   - definition: The active definition supplying the current display name.
    ///   - amount: The amount and unit to repeat.
    ///   - caffeineVariant: The previously selected, still-supported preparation.
    ///   - shotCount: The previously selected, still-supported shot count.
    init(
        definition: DrinkDefinition,
        amount: DrinkAmount,
        caffeineVariant: CaffeineVariant,
        shotCount: Int?,
        isNonAlcoholic: Bool = false,
        alcoholABV: Double? = nil
    ) {
        self.drinkID = definition.id
        self.drinkName = definition.name
        self.amount = amount
        self.caffeineVariant = caffeineVariant
        self.shotCount = shotCount
        self.isNonAlcoholic = isNonAlcoholic
        self.alcoholABV = alcoholABV
        self.showsCaffeineVariant = definition.caffeineOptions.count > 1
    }

    /// The displayed amount, current name and any preparation choices.
    func label(displayedAs unit: LiquidUnit, locale: Locale = .current) -> String {
        let volume = VolumeFormatter(locale: locale).string(
            from: amount.volume, displayedAs: unit,
            fractionLength: unit == .milliliters ? 0...0 : 0...3
        )
        var text = "\(volume) of \(drinkName)"
        if showsCaffeineVariant {
            text += " (\(caffeineVariant.displayName))"
        }
        if let shotCount {
            text += shotCount == 1 ? ", 1 shot" : ", \(shotCount) shots"
        }
        if isNonAlcoholic {
            text += " (Non-alcoholic)"
        } else if let alcoholABV {
            text += " (\((alcoholABV * 100).formatted(.number.precision(.fractionLength(0...1))))% ABV)"
        }
        return text
    }

    /// Creates a new entry under current rules instead of copying historical estimates.
    ///
    /// - Parameters:
    ///   - resolver: The catalogue resolver to use for the new submission.
    ///   - date: The date and time to log the repeated drink for.
    /// - Returns: A new entry with fresh identity, timestamps and estimates.
    /// - Throws: A resolution or calculation error if the shortcut is no longer valid.
    func drinkEntry(
        using resolver: DrinkCatalogueSnapshotResolver,
        date: Date = Date()
    ) throws -> DrinkEntry {
        let draft = AddDrinkDraft(
            drinkID: drinkID,
            volumeValue: amount.value,
            unit: amount.unit,
            caffeineVariant: caffeineVariant,
            shotCount: shotCount,
            isNonAlcoholic: isNonAlcoholic,
            alcoholABV: alcoholABV
        )
        return try draft.drinkEntry(using: resolver, date: date)
    }
}
