//
//  PersistentDrinkEntry.swift
//  Watered
//
//  Created by Frank Sedivy on 05/09/2026.
//

import Foundation
import SwiftData

/// Stores drink history and fields for captured catalogue estimates in SwiftData.
///
/// Storage values are mapped to DrinkEntry for calculations and display.
@Model
final class PersistentDrinkEntry {
    var id: UUID = UUID()
    var drinkTypeID: String = "water"
    var volumeValue: Double = 0
    var unitID: String = "milliliters"
    var loggedAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var source: String = "manual"
    
    // MARK: - Catalogue snapshot
    
    /// The catalogue identifier, or nil when this entry has no captured snapshot.
    var catalogueDrinkID: String?  = nil
    
    /// The dirnk name captured when the entry was logged.
    var catalogueDrinkName: String? = nil
    
    /// The raw identifier of the selected caffeine preparation.
    var caffeineVariantID: String? = nil
    
    /// The selected shot count, or nil when shots do not apply.
    var shotCount: Int? = nil
    
    /// The captured hydration contribution in millilitres.
    ///
    /// Nil means unknown when a snapshot is present.
    var hydrationContribution: Double?  = nil
    
    /// The captured caffeine estimate in milligrams.
    ///
    /// Nil means unknown when a snapshot is present' zero remains a known value.
    var caffeineAmount: Double? = nil
    
    /// The catalogue content version used when logging.
    var catalogueVersion: String? = nil
    
    /// The calculation version used to resolve the captured estimates.
    var calculationVersion: String? = nil
    
    init(
        id: UUID = UUID(),
        drinkTypeID: String,
        volumeValue: Double,
        unitID: String,
        loggedAt: Date,
        createdAt: Date,
        updatedAt: Date,
        source: String
    ) {
        self.id = id
        self.drinkTypeID = drinkTypeID
        self.volumeValue = volumeValue
        self.unitID = unitID
        self.loggedAt = loggedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }
    
    
    /// Creates a persistent record from a logged drink.
    ///
    /// Copies identity, amount, timestamps, source and captured catalogue facts into storage fields.
    ///
    /// - Parameter drinkEntry: The logged drink to store.
    convenience init(drinkEntry: DrinkEntry) {
        self.init(
            id: drinkEntry.id,
            drinkTypeID: drinkEntry.type.persistenceIdentifier,
            volumeValue: drinkEntry.amount.value,
            unitID: drinkEntry.amount.unit.persistenceIdentifier,
            loggedAt: drinkEntry.loggedAt,
            createdAt: drinkEntry.createdAt,
            updatedAt: drinkEntry.updatedAt,
            source: drinkEntry.source.rawValue
        )
        
        if let snapshot = drinkEntry.catalogueSnapshot {
            catalogueDrinkID = snapshot.drinkID
            catalogueDrinkName = snapshot.drinkName
            caffeineVariantID = snapshot.caffeineVariant.rawValue
            shotCount = snapshot.shotCount
            hydrationContribution = snapshot.hydrationContribution
            caffeineAmount = snapshot.caffeineAmount
            catalogueVersion = snapshot.catalogueVersion
            calculationVersion = snapshot.calculationVersion
        }
    }
    
    /// Recreates a logged drink from its stored values.
    ///
    /// - Returns:The restored entry, or nil if its drink type, unit or source identifier is not recognised or a captured
    ///   catalogue snapshot is incomplete
    func drinkEntry() -> DrinkEntry? {
        guard let drinkType = DrinkType(persistenceIdentifier: drinkTypeID),
              let liquidUnit = LiquidUnit(persistenceIdentifier: unitID),
              let drinkEntrySource = DrinkEntrySource(rawValue: source)
        else {
            return nil
        }
        
        let snapshot: DrinkCatalogueSnapshot?
        
        if let drinkID = catalogueDrinkID {
            guard let drinkName = catalogueDrinkName,
                  let variantID = caffeineVariantID,
                  let variant = CaffeineVariant(rawValue: variantID),
                  let catalogueVersion,
                  let calculationVersion
            else {
                return nil
            }
            
            snapshot = DrinkCatalogueSnapshot(
                drinkID: drinkID,
                drinkName: drinkName,
                caffeineVariant: variant,
                shotCount: shotCount,
                hydrationContribution: hydrationContribution,
                caffeineAmount: caffeineAmount,
                catalogueVersion: catalogueVersion,
                calculationVersion: calculationVersion
            )
        } else {
            snapshot = nil
        }
        
        return DrinkEntry(
            id: id,
            type: drinkType,
            amount: DrinkAmount(value: volumeValue, unit: liquidUnit),
            date: loggedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: drinkEntrySource,
            catalogueSnapshot: snapshot
        )
    }
    
}
