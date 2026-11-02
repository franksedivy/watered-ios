//
//  DrinkEntry.swift
//  Watered
//
//  Created by Frank Sedivy on 30/06/2026.
//

import Foundation

/// One logged drink with immutable catalogue facts, amount, timestamps and provenance.
nonisolated struct DrinkEntry: Identifiable, CustomStringConvertible {
    let id: UUID
    let amount: DrinkAmount
    let date: Date
    let createdAt: Date
    let updatedAt: Date
    let source: DrinkEntrySource

    /// The identity, preparation and resolved estimates captured when logging.
    let catalogueSnapshot: DrinkCatalogueSnapshot

    /// The saved name, retained even when the catalogue definition becomes unavailable.
    var displayName: String {
        catalogueSnapshot.drinkName
    }

    /// The stable identity of the logged catalogue drink.
    var drinkID: String {
        catalogueSnapshot.drinkID
    }

    var description: String {
        "\(displayName), \(amount)"
    }

    /// The date and time the drink was logged for, independent of its creation time.
    var loggedAt: Date {
        date
    }

    /// Creates an entry from facts already resolved at logging time.
    ///
    /// - Parameters:
    ///   - id: The entry UUID, independent of its catalogue drink ID.
    ///   - amount: The consumed liquid amount and its original unit.
    ///   - date: The date and time the drink was logged for.
    ///   - createdAt: When the entry was first created.
    ///   - updatedAt: When the entry was last updated.
    ///   - source: The origin of the logged entry.
    ///   - catalogueSnapshot: Captured facts; later catalogue changes do not reinterpret them.
    init(
        id: UUID = UUID(),
        amount: DrinkAmount,
        date: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: DrinkEntrySource = .manual,
        catalogueSnapshot: DrinkCatalogueSnapshot
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.catalogueSnapshot = catalogueSnapshot
    }

    /// The saved hydration estimate in millilitres, or nil when it is unknown.
    ///
    /// Zero and negative estimates are preserved without consulting the current catalogue.
    var hydrationContributionVolume: Measurement<UnitVolume>? {
        guard let contribution = catalogueSnapshot.hydrationContribution else {
            return nil
        }
        return VolumeCalculation.measurement(fromBaseValue: contribution)
    }

    /// The saved hydration contribution divided by the consumed volume in matching units.
    ///
    /// Nil for unknown estimates or invalid amounts. Zero and negative ratios are preserved.
    var hydrationContributionRatio: Double? {
        let volume = VolumeCalculation.baseValue(from: amount.volume)
        guard let contribution = catalogueSnapshot.hydrationContribution,
              contribution.isFinite, volume.isFinite, volume > 0
        else {
            return nil
        }
        let ratio = contribution / volume
        return ratio.isFinite ? ratio : nil
    }
}
