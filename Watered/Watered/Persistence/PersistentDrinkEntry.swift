//
//  PersistentDrinkEntry.swift
//  Watered
//
//  Created by Frank Sedivy on 05/09/2026.
//

import Foundation
import SwiftData

/// Stores the immutable catalogue facts and metadata of a logged drink.
///
/// Snapshot fields retain their storage names and optional representation. Restoration
/// requires complete identity and version metadata; nil estimates remain valid unknowns.
@Model
final class PersistentDrinkEntry {
    var id: UUID = UUID()
    var volumeValue: Double = 0
    var unitID: String = "milliliters"
    var loggedAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var source: String = "manual"

    /// The saved catalogue identity, independent of the current catalogue.
    var catalogueDrinkID: String? = nil

    /// The name captured when logging, retained for unavailable drinks.
    var catalogueDrinkName: String? = nil

    /// The selected caffeine preparation's raw value.
    var caffeineVariantID: String? = nil

    /// The selected shot count, or nil when shots do not apply.
    var shotCount: Int? = nil

    /// The captured hydration estimate in millilitres; nil means unknown.
    var hydrationContribution: Double? = nil

    /// The captured caffeine estimate in milligrams; nil means unknown, zero means known zero.
    var caffeineAmount: Double? = nil

    /// The catalogue content version used when logging.
    var catalogueVersion: String? = nil

    /// The calculation version used to produce the saved estimates.
    var calculationVersion: String? = nil

    /// The original JSON schema version, or nil for entries that did not capture it.
    var catalogueSchemaVersion: Int? = nil

    /// Copies a logged entry and its captured snapshot into storage fields.
    ///
    /// - Parameter drinkEntry: The entry whose facts and metadata must be preserved.
    init(drinkEntry: DrinkEntry) {
        let snapshot = drinkEntry.catalogueSnapshot
        self.id = drinkEntry.id
        self.volumeValue = drinkEntry.amount.value
        self.unitID = drinkEntry.amount.unit.persistenceIdentifier
        self.loggedAt = drinkEntry.loggedAt
        self.createdAt = drinkEntry.createdAt
        self.updatedAt = drinkEntry.updatedAt
        self.source = drinkEntry.source.rawValue
        self.catalogueDrinkID = snapshot.drinkID
        self.catalogueDrinkName = snapshot.drinkName
        self.caffeineVariantID = snapshot.caffeineVariant.rawValue
        self.shotCount = snapshot.shotCount
        self.hydrationContribution = snapshot.hydrationContribution
        self.caffeineAmount = snapshot.caffeineAmount
        self.catalogueVersion = snapshot.catalogueVersion
        self.calculationVersion = snapshot.calculationVersion
        self.catalogueSchemaVersion = snapshot.catalogueSchemaVersion
    }

    /// Restores an entry entirely from saved facts, without a catalogue lookup.
    ///
    /// - Returns: The restored entry, or nil for incomplete metadata or invalid stored values.
    /// - Important: Old development rows without snapshots are not reinterpreted or deleted.
    func drinkEntry() -> DrinkEntry? {
        guard let drinkID = catalogueDrinkID, !drinkID.isEmpty,
              let drinkName = catalogueDrinkName, !drinkName.isEmpty,
              let variantID = caffeineVariantID,
              let variant = CaffeineVariant(rawValue: variantID),
              let catalogueVersion, !catalogueVersion.isEmpty,
              let calculationVersion, !calculationVersion.isEmpty,
              let unit = LiquidUnit(persistenceIdentifier: unitID),
              let entrySource = DrinkEntrySource(rawValue: source),
              volumeValue.isFinite, volumeValue > 0
        else {
            return nil
        }

        if let hydrationContribution, !hydrationContribution.isFinite {
            return nil
        }
        if let caffeineAmount, !caffeineAmount.isFinite || caffeineAmount < 0 {
            return nil
        }
        if let shotCount, shotCount < 0 {
            return nil
        }

        let snapshot = DrinkCatalogueSnapshot(
            drinkID: drinkID,
            drinkName: drinkName,
            caffeineVariant: variant,
            shotCount: shotCount,
            hydrationContribution: hydrationContribution,
            caffeineAmount: caffeineAmount,
            catalogueVersion: catalogueVersion,
            calculationVersion: calculationVersion,
            catalogueSchemaVersion: catalogueSchemaVersion
        )
        return DrinkEntry(
            id: id,
            amount: DrinkAmount(value: volumeValue, unit: unit),
            date: loggedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: entrySource,
            catalogueSnapshot: snapshot
        )
    }
}
