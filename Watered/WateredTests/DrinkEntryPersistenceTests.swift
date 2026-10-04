//
//  DrinkEntryPersistenceTests.swift
//  Watered
//
//  Created by Frank Sedivy on 04/10/2026.
//
import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct DrinkEntryPersistenceTests {
    
    // GIVEN an empty store, when a drink is saved,
    // THEN a separate context reads one record with its identity, amount, dates, and source
    // preserved.
    @Test func savingDrinkPersistsItsValues() throws {
        let container = try ModelContainer(
           for: PersistentDrinkEntry.self,
           configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let entry = DrinkEntry(
           type: .water,
           amount: DrinkAmount(value: 330, unit: .milliliters),
           date: Date(timeIntervalSince1970: 1000),
           createdAt: Date(timeIntervalSince1970: 2000),
           updatedAt: Date(timeIntervalSince1970: 3000),
           source: .manual
        )

        try DrinkEntryPersistence.save(entry, in: context)

        let verificationContext = ModelContext(container)
        let records = try verificationContext.fetch(
           FetchDescriptor<PersistentDrinkEntry>()
        )

        #expect(records.count == 1)

        let savedEntry = try #require(records.first)
        #expect(savedEntry.id == entry.id)
        #expect(savedEntry.drinkTypeID == "water")
        #expect(savedEntry.volumeValue == 330)
        #expect(savedEntry.unitID == "milliliters")
        #expect(savedEntry.loggedAt == entry.loggedAt)
        #expect(savedEntry.createdAt == entry.createdAt)
        #expect(savedEntry.updatedAt == entry.updatedAt)
        #expect(savedEntry.source == "manual")
        #expect(context.hasChanges == false)
    }
    
    // GIVEN an existing saved drink, when another submission fails before saving,
    // THEN rollback removes the new insertion and preserves the saved drink.
    @Test func failedSavePreservesPreviouslySavedDrink() throws {
        let container = try ModelContainer(
            for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let existingEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000)
        )
        try DrinkEntryPersistence.save(existingEntry, in: context)

        let newEntry = DrinkEntry(
            type: .tea,
            amount: DrinkAmount(value: 500, unit: .milliliters),
            date: Date(timeIntervalSince1970: 2000)
        )

        #expect(throws: CocoaError.self) {
            try DrinkEntryPersistence.save(
                newEntry,
                in: context,
                beforeSave: {
                    throw CocoaError(.fileWriteUnknown)
                }
            )
        }

        let currentRecords = try context.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        #expect(currentRecords.count == 1)
        #expect(currentRecords.first?.id == existingEntry.id)
        #expect(context.hasChanges == false)

        let verificationContext = ModelContext(container)
        let savedRecords = try verificationContext.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        #expect(savedRecords.count == 1)
        #expect(savedRecords.first?.id == existingEntry.id)
    }
    
    // Given two saved drinks with identical values, when one is deleted,
    // then only its identifier is returned and the other drink remains saved.
    @Test func deletingOneDrinkPreservesIdenticalDrink() throws {
        let container = try ModelContainer(
            for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let date = Date(timeIntervalSince1970: 1000)
        let firstEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: date
        )
        let secondEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: date
        )

        try DrinkEntryPersistence.save(firstEntry, in: context)
        try DrinkEntryPersistence.save(secondEntry, in: context)

        let records = try context.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        let entryToDelete = try #require(records.first { record in
            record.id == firstEntry.id
        })

        let deletedIDs = try DrinkEntryPersistence.delete(
            [entryToDelete],
            in: context
        )

        #expect(deletedIDs == Set([firstEntry.id]))
        #expect(context.hasChanges == false)

        let verificationContext = ModelContext(container)
        let remainingRecords = try verificationContext.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )

        #expect(remainingRecords.count == 1)
        #expect(remainingRecords.first?.id == secondEntry.id)
    }
    
    // GIVEN saved drinks and an unsaved unit preference, when all drinks are deleted,
    // THEN the drinks are removed and the settings change is saved.
    @Test func deletingAllDrinksPreservesPendingSettingsChange() throws {
        let container = try ModelContainer(
            for: PersistentDrinkEntry.self,
            PersistentAppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let settings = PersistentAppSettings(
            appSettings: AppSettings.defaults(
                for: Locale(identifier: "en_GB")
            )
        )
        context.insert(settings)
        try context.save()

        let firstEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000)
        )
        let secondEntry = DrinkEntry(
            type: .tea,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 2000)
        )
        try DrinkEntryPersistence.save(firstEntry, in: context)
        try DrinkEntryPersistence.save(secondEntry, in: context)

        settings.displayUnitID = LiquidUnit.usFluidOunces.persistenceIdentifier
        #expect(context.hasChanges)

        let records = try context.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        let deletedIDs = try DrinkEntryPersistence.delete(records, in: context)

        #expect(deletedIDs == Set([firstEntry.id, secondEntry.id]))
        #expect(context.hasChanges == false)

        let verificationContext = ModelContext(container)
        let remainingDrinks = try verificationContext.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )

        #expect(remainingDrinks.isEmpty)
        #expect(savedSettings.count == 1)
        let savedPreference = try #require(savedSettings.first)
        #expect(
            savedPreference.displayUnitID ==
            LiquidUnit.usFluidOunces.persistenceIdentifier
        )
    }
    
    // GIVEN a saved drink and an unsaved unit preference, when deletion fails,
    // THEN the drink remains and the settings change is preserved.
    @Test func failedDeletionPreservesDrinkAndPendingSettingsChange() throws {
        let container = try ModelContainer(
            for: PersistentDrinkEntry.self,
            PersistentAppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let settings = PersistentAppSettings(
            appSettings: AppSettings.defaults(
                for: Locale(identifier: "en_GB")
            )
        )
        context.insert(settings)
        try context.save()

        let entry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000)
        )
        try DrinkEntryPersistence.save(entry, in: context)

        settings.displayUnitID = LiquidUnit.usFluidOunces.persistenceIdentifier
        #expect(context.hasChanges)

        let records = try context.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )

        #expect(throws: CocoaError.self) {
            try DrinkEntryPersistence.delete(
                records,
                in: context,
                beforeSave: {
                    throw CocoaError(.fileWriteUnknown)
                }
            )
        }

        #expect(context.hasChanges == false)
        let currentRecords = try context.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        #expect(currentRecords.count == 1)
        #expect(currentRecords.first?.id == entry.id)

        let verificationContext = ModelContext(container)
        let savedDrinks = try verificationContext.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )

        #expect(savedDrinks.count == 1)
        #expect(savedDrinks.first?.id == entry.id)
        #expect(savedSettings.count == 1)
        let savedPreference = try #require(savedSettings.first)
        #expect(
            savedPreference.displayUnitID ==
            LiquidUnit.usFluidOunces.persistenceIdentifier
        )
    }
    
    // GIVEN an unsaved unit preference and no drinks to delete, when deletion is requested,
    // THEN no IDs are returned and the pending edit remains unsaved.
    @Test func deletingNoDrinksLeavesPendingChangesUntouched() throws {
        let container = try ModelContainer(
            for: PersistentDrinkEntry.self,
            PersistentAppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let settings = PersistentAppSettings(
            appSettings: AppSettings.defaults(
                for: Locale(identifier: "en_GB")
            )
        )
        context.insert(settings)
        try context.save()

        settings.displayUnitID = LiquidUnit.usFluidOunces.persistenceIdentifier
        #expect(context.hasChanges)

        var callbackWasCalled = false
        let deletedIDs = try DrinkEntryPersistence.delete(
            [],
            in: context,
            beforeSave: {
                callbackWasCalled = true
            }
        )

        #expect(deletedIDs.isEmpty)
        #expect(callbackWasCalled == false)
        #expect(context.hasChanges)
        #expect(
            settings.displayUnitID ==
            LiquidUnit.usFluidOunces.persistenceIdentifier
        )

        let verificationContext = ModelContext(container)
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        #expect(savedSettings.count == 1)

        let savedPreference = try #require(savedSettings.first)
        #expect(
            savedPreference.displayUnitID ==
            LiquidUnit.milliliters.persistenceIdentifier
        )
    }
}

