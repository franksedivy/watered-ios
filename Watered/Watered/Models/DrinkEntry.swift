//
//  DrinkEntry.swift
//  Watered
//
//  Created by Frank Sedivy on 30/06/2026.
//

import Foundation

nonisolated struct DrinkEntry: Identifiable, CustomStringConvertible {
    let id: UUID
    let type: DrinkType
    let amount: DrinkAmount
    let date: Date
    let createdAt: Date
    let updatedAt: Date
    let source: DrinkEntrySource
    
    /// The catalogue facts captured when this drink was logged.
    ///
    /// Temporarily optional while existing entry creation is converted.
    let catalogueSnapshot: DrinkCatalogueSnapshot?
    
    var description: String {
        "\(displayName), \(amount)"
    }
    
    /// The captured drink anem, falling back to the legacy type name.
    var displayName: String {
        catalogueSnapshot?.drinkName ?? type.rawValue
    }
    
    /// The date and time this drink was logged for.
    ///
    /// Aliases 'date' and is used for calendar-day filtering and persistence. This can differ from when the entry was created
    /// or last updated.
    var loggedAt: Date {
        date
    }
    
    
    /// Creates a logged drink with identity, amount, dates and provenance.
    ///
    /// - Parameter catalogueSnapshot: The catalogue facts captured for this drink. Defaults to nil while existing
    ///   callers are being converted.
    init(
        id: UUID = UUID(),
        type: DrinkType,
        amount: DrinkAmount,
        date: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: DrinkEntrySource = .manual,
        catalogueSnapshot: DrinkCatalogueSnapshot? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.catalogueSnapshot = catalogueSnapshot
    }
    
    // MARK: - Hydration Contribution
    
    /// Returns the captured hydration contribution when a snapshot exists.
    ///
    /// An unknown captured contribution remains nil. Entries without a snapshot temporarily use the existing DrinkType
    /// calculation while callers are converted.
    var hydrationContributionVolume: Measurement<UnitVolume>? {
        if let snapshot = catalogueSnapshot {
            guard let contribution = snapshot.hydrationContribution else {
                return nil
            }
            return VolumeCalculation.measurement(fromBaseValue: contribution)
        }
        
        switch type.hydrationContributionRule {
        case .ratio(let ratio):
            return Measurement(
                value: amount.volume.value * ratio,
                unit: amount.volume.unit
            )
        case .alcohol(let defaultABV):
            let alcoholVolume = amount.volume.value * defaultABV
            let estimatedHydrationPenalty = alcoholVolume * 10
            let estimatedHydrationContribution = amount.volume.value - estimatedHydrationPenalty
            
            return Measurement(
                value: estimatedHydrationContribution,
                unit: amount.volume.unit
            )
        case .unknown:
            return nil
        }
    }
}
