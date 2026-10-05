//
//  AppSettingsPersistenceTests.swift
//  Watered
//
//  Created by Frank Sedivy on 27/09/2026.
//

import Foundation
import Testing
import SwiftData
@testable import Watered

@MainActor
struct AppSettingsPersistenceTests {
    // MARK: - App Settings Persistence

    // Given an empty store, when settings are loaded twice, then one settings
    // record and one default-goal record are saved with their original timestamps.
    @MainActor
    @Test func loadingSettingsCreatesInitialGoalHistoryOnlyOnce() throws {
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let initialDate = Date(timeIntervalSince1970: 1000)
        let laterDate = Date(timeIntervalSince1970: 2000)

        let initialSettings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: initialDate
        )
        let loadedSettings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: laterDate
        )

        #expect(initialSettings.persistentModelID == loadedSettings.persistentModelID)

        // Read through a separate context to check saved records.
        let verificationContext = ModelContext(container)
        let settingsRecords = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let historyRecords = try verificationContext.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )

        #expect(settingsRecords.count == 1)
        #expect(historyRecords.count == 1)

        let settings = try #require(settingsRecords.first)
        let history = try #require(historyRecords.first)

        #expect(settings.displayUnitID == defaults.displayUnit.persistenceIdentifier)
        #expect(settings.dailyGoalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(settings.dailyGoalUnitID == "milliliters")
        #expect(settings.createdAt == initialDate)
        #expect(settings.updatedAt == initialDate)
        #expect(history.goalValue == settings.dailyGoalValue)
        #expect(history.goalUnitID == settings.dailyGoalUnitID)
        #expect(history.changedAt == initialDate)
        #expect(history.source == HydrationGoalSource.appDefault.rawValue)
    }
    
    // GIVEN saved settings and initial goal history, when a different goal is committed,
    // THEN settings reflect the new goal and one manual record is appended without
    // changing the original default-goal record.
    @Test func savingChangedGoalUpdatesSettingsAndPreservesHistory() throws {
        let container = try ModelContainer(
           for: PersistentAppSettings.self,
           PersistentHydrationGoalChange.self,
           configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let initialDate = Date(timeIntervalSince1970: 1000)
        let changedDate = Date(timeIntervalSince1970: 2000)
        let settings = try AppSettingsPersistence.loadOrCreate(
           defaults: defaults,
           in: context,
           at: initialDate
        )
        let initialRecords = try context.fetch(
           FetchDescriptor<PersistentHydrationGoalChange>()
        )
        let originalID = try #require(initialRecords.first).id
        let newGoal = HydrationGoal(amount: DrinkAmount(value: 3000, unit: .milliliters))

        let didChange = try AppSettingsPersistence.saveGoal(
           newGoal,
           source: .manual,
           settings: settings,
           in: context,
           at: changedDate
        )

        let verificationContext = ModelContext(container)
        let savedSettings = try verificationContext.fetch(
           FetchDescriptor<PersistentAppSettings>()
        )
        let history = try verificationContext.fetch(
           FetchDescriptor<PersistentHydrationGoalChange>(
               sortBy: [SortDescriptor(\.changedAt)]
           )
        )

        #expect(didChange)
        #expect(savedSettings.count == 1)
        #expect(history.count == 2)

        let saved = try #require(savedSettings.first)
        let original = try #require(history.first)
        let latest = try #require(history.last)

        #expect(saved.dailyGoalValue == 3000)
        #expect(saved.dailyGoalUnitID == "milliliters")
        #expect(saved.createdAt == initialDate)
        #expect(saved.updatedAt == changedDate)
        #expect(original.id == originalID)
        #expect(original.goalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(original.goalUnitID == "milliliters")
        #expect(original.changedAt == initialDate)
        #expect(original.source == HydrationGoalSource.appDefault.rawValue)
        #expect(latest.id != originalID)
        #expect(latest.goalValue == saved.dailyGoalValue)
        #expect(latest.goalUnitID == saved.dailyGoalUnitID)
        #expect(latest.changedAt == changedDate)
        #expect(latest.source == HydrationGoalSource.manual.rawValue)
    }
    
    // Given saved settings and initial goal history, when the same goal is submitted,
    // then no change is reported, no history is appended, and timestamps stay unchanged.
    @Test func savingUnchangedGoalPreservesHistoryAndTimestamps() throws {
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let initialDate = Date(timeIntervalSince1970: 1000)
        let laterDate = Date(timeIntervalSince1970: 2000)
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: initialDate
        )
        let initialRecords = try context.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )
        let originalID = try #require(initialRecords.first).id

        let didChange = try AppSettingsPersistence.saveGoal(
            defaults.dailyHydrationGoal,
            source: .manual,
            settings: settings,
            in: context,
            at: laterDate
        )

        #expect(!didChange)
        #expect(!context.hasChanges)

        let verificationContext = ModelContext(container)
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let history = try verificationContext.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )

        #expect(savedSettings.count == 1)
        #expect(history.count == 1)

        let saved = try #require(savedSettings.first)
        let original = try #require(history.first)

        #expect(saved.dailyGoalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(saved.dailyGoalUnitID == "milliliters")
        #expect(saved.createdAt == initialDate)
        #expect(saved.updatedAt == initialDate)
        #expect(original.id == originalID)
        #expect(original.goalValue == saved.dailyGoalValue)
        #expect(original.goalUnitID == saved.dailyGoalUnitID)
        #expect(original.changedAt == initialDate)
        #expect(original.source == HydrationGoalSource.appDefault.rawValue)
    }
    
    // Given a saved goal, when its unit changes but its numeric value stays the same,
    // then the new unit is saved and a separate goal-history record is appended.
    @Test func savingGoalWithDifferentUnitRecordsAChange() throws {
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let initialDate = Date(timeIntervalSince1970: 1000)
        let changedDate = Date(timeIntervalSince1970: 2000)
        let defaults = AppSettings(
            displayUnit: .usFluidOunces,
            dailyHydrationGoal: HydrationGoal(
                amount: DrinkAmount(value: 90, unit: .usFluidOunces)
            )
        )
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: initialDate
        )
        let newGoal = HydrationGoal(
            amount: DrinkAmount(value: 90, unit: .imperialFluidOunces)
        )

        let didChange = try AppSettingsPersistence.saveGoal(
            newGoal,
            source: .manual,
            settings: settings,
            in: context,
            at: changedDate
        )

        let verificationContext = ModelContext(container)
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let history = try verificationContext.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>(
                sortBy: [SortDescriptor(\.changedAt)]
            )
        )
        let saved = try #require(savedSettings.first)
        let original = try #require(history.first)
        let latest = try #require(history.last)

        #expect(didChange)
        #expect(history.count == 2)
        #expect(saved.dailyGoalValue == 90)
        #expect(saved.dailyGoalUnitID == "imperialFluidOunces")
        #expect(saved.updatedAt == changedDate)
        #expect(original.goalValue == 90)
        #expect(original.goalUnitID == "usFluidOunces")
        #expect(latest.goalValue == 90)
        #expect(latest.goalUnitID == "imperialFluidOunces")
        #expect(latest.changedAt == changedDate)
        #expect(latest.source == HydrationGoalSource.manual.rawValue)
    }
    
    // Given goal history saved to disk, when a new container opens the same store,
    // then current settings and both historical records retain their saved values.
    @Test func goalHistorySurvivesReopeningDiskStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let storeURL = directory.appendingPathComponent("GoalHistory.store")
        let expectedIDs = try writeGoalHistory(to: storeURL)

        let configuration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let settingsRecords = try context.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let history = try context.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>(
                sortBy: [SortDescriptor(\.changedAt)]
            )
        )
        let restoredIDs = history.map { change in
            change.id
        }

        #expect(settingsRecords.count == 1)
        #expect(history.count == 2)
        #expect(restoredIDs == expectedIDs)

        let settings = try #require(settingsRecords.first)
        let original = try #require(history.first)
        let latest = try #require(history.last)
        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))

        #expect(settings.dailyGoalValue == 3000)
        #expect(settings.dailyGoalUnitID == "milliliters")
        #expect(settings.createdAt == Date(timeIntervalSince1970: 1000))
        #expect(settings.updatedAt == Date(timeIntervalSince1970: 2000))
        #expect(original.goalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(original.goalUnitID == "milliliters")
        #expect(original.changedAt == Date(timeIntervalSince1970: 1000))
        #expect(original.source == HydrationGoalSource.appDefault.rawValue)
        #expect(latest.goalValue == 3000)
        #expect(latest.goalUnitID == "milliliters")
        #expect(latest.changedAt == Date(timeIntervalSince1970: 2000))
        #expect(latest.source == HydrationGoalSource.manual.rawValue)
    }
    
    // GIVEN saved settings and initial goal history, when the display unit changes,
    // THEN the new unit is saved without changing the goal or its history.
    @Test func savingDisplayUnitPreservesGoalHistory() throws {
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let initialDate = Date(timeIntervalSince1970: 1000)
        let changedDate = Date(timeIntervalSince1970: 2000)
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: initialDate
        )
        let initialHistory = try context.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )
        let originalID = try #require(initialHistory.first).id

        let didChange = try AppSettingsPersistence.saveDisplayUnit(
            .usFluidOunces,
            settings: settings,
            in: context,
            at: changedDate
        )

        let verificationContext = ModelContext(container)
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let history = try verificationContext.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )

        #expect(didChange)
        #expect(context.hasChanges == false)
        #expect(savedSettings.count == 1)
        #expect(history.count == 1)

        let saved = try #require(savedSettings.first)
        let original = try #require(history.first)

        #expect(saved.displayUnitID == "usFluidOunces")
        #expect(saved.createdAt == initialDate)
        #expect(saved.updatedAt == changedDate)
        #expect(saved.dailyGoalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(saved.dailyGoalUnitID == "milliliters")
        #expect(original.id == originalID)
        #expect(original.goalValue == saved.dailyGoalValue)
        #expect(original.goalUnitID == saved.dailyGoalUnitID)
        #expect(original.changedAt == initialDate)
        #expect(original.source == HydrationGoalSource.appDefault.rawValue)
    }
    
    // GIVEN saved settings, when the existing display unit is submitted,
    // THEN no save callback runs and settings and goal history remain unchanged.
    @Test func savingUnchangedDisplayUnitSkipsSaving() throws {
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let initialDate = Date(timeIntervalSince1970: 1000)
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: initialDate
        )
        var didCallBeforeSave = false

        let didChange = try AppSettingsPersistence.saveDisplayUnit(
            defaults.displayUnit,
            settings: settings,
            in: context,
            at: Date(timeIntervalSince1970: 2000),
            beforeSave: {
                didCallBeforeSave = true
            }
        )

        #expect(didChange == false)
        #expect(didCallBeforeSave == false)
        #expect(context.hasChanges == false)

        let verificationContext = ModelContext(container)
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let history = try verificationContext.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )
        #expect(savedSettings.count == 1)
        #expect(history.count == 1)

        let saved = try #require(savedSettings.first)
        let original = try #require(history.first)
        #expect(saved.displayUnitID == defaults.displayUnit.persistenceIdentifier)
        #expect(saved.createdAt == initialDate)
        #expect(saved.updatedAt == initialDate)
        #expect(saved.dailyGoalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(saved.dailyGoalUnitID == "milliliters")
        #expect(original.changedAt == initialDate)
        #expect(original.goalValue == saved.dailyGoalValue)
        #expect(original.goalUnitID == saved.dailyGoalUnitID)
        #expect(original.source == HydrationGoalSource.appDefault.rawValue)
    }
    
    // GIVEN saved settings, when a display-unit save fails after mutation,
    // THEN the previous unit and timestamp are restored and goal history is preserved.
    @Test func failedDisplayUnitSaveRestoresPreviousSettings() throws {
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let initialDate = Date(timeIntervalSince1970: 1000)
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: initialDate
        )
        let initialHistory = try context.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )
        let originalID = try #require(initialHistory.first).id

        #expect(throws: CocoaError.self) {
            try AppSettingsPersistence.saveDisplayUnit(
                .usFluidOunces,
                settings: settings,
                in: context,
                at: Date(timeIntervalSince1970: 2000),
                beforeSave: {
                    throw CocoaError(.fileWriteUnknown)
                }
            )
        }

        #expect(settings.displayUnitID == defaults.displayUnit.persistenceIdentifier)
        #expect(settings.updatedAt == initialDate)
        #expect(context.hasChanges == false)

        let verificationContext = ModelContext(container)
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let history = try verificationContext.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )
        #expect(savedSettings.count == 1)
        #expect(history.count == 1)

        let saved = try #require(savedSettings.first)
        let original = try #require(history.first)
        #expect(saved.displayUnitID == defaults.displayUnit.persistenceIdentifier)
        #expect(saved.createdAt == initialDate)
        #expect(saved.updatedAt == initialDate)
        #expect(saved.dailyGoalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(saved.dailyGoalUnitID == "milliliters")
        #expect(original.id == originalID)
        #expect(original.changedAt == initialDate)
        #expect(original.goalValue == saved.dailyGoalValue)
        #expect(original.goalUnitID == saved.dailyGoalUnitID)
        #expect(original.source == HydrationGoalSource.appDefault.rawValue)
    }
    
    // GIVEN an unsaved drink, when a display-unit save fails,
    // THEN the drink is saved first and survives the settings rollback.
    @Test func failedDisplayUnitSavePreservesPendingDrink() throws {
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            PersistentDrinkEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let initialDate = Date(timeIntervalSince1970: 1000)
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: initialDate
        )
        let drink = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: initialDate
        )
        context.insert(PersistentDrinkEntry(drinkEntry: drink))
        #expect(context.hasChanges)

        #expect(throws: CocoaError.self) {
            try AppSettingsPersistence.saveDisplayUnit(
                .usFluidOunces,
                settings: settings,
                in: context,
                at: Date(timeIntervalSince1970: 2000),
                beforeSave: {
                    throw CocoaError(.fileWriteUnknown)
                }
            )
        }

        #expect(context.hasChanges == false)

        let verificationContext = ModelContext(container)
        let drinks = try verificationContext.fetch(
            FetchDescriptor<PersistentDrinkEntry>()
        )
        let savedSettings = try verificationContext.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )

        #expect(drinks.count == 1)
        let savedDrink = try #require(drinks.first)
        #expect(savedDrink.id == drink.id)
        #expect(savedDrink.volumeValue == 330)

        #expect(savedSettings.count == 1)
        let saved = try #require(savedSettings.first)
        #expect(saved.displayUnitID == defaults.displayUnit.persistenceIdentifier)
        #expect(saved.updatedAt == initialDate)
    }
    
    // Given a display unit saved to disk, when a new container opens the same store,
    // then the unit and settings timestamps persist without changing goal history.
    @Test func displayUnitSurvivesReopeningDiskStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let storeURL = directory.appendingPathComponent("DisplayUnit.store")
        let originalID = try writeChangedDisplayUnit(to: storeURL)
        let configuration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let settingsRecords = try context.fetch(
            FetchDescriptor<PersistentAppSettings>()
        )
        let history = try context.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )
        #expect(settingsRecords.count == 1)
        #expect(history.count == 1)

        let settings = try #require(settingsRecords.first)
        let original = try #require(history.first)
        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))

        #expect(settings.displayUnitID == "usFluidOunces")
        #expect(settings.createdAt == Date(timeIntervalSince1970: 1000))
        #expect(settings.updatedAt == Date(timeIntervalSince1970: 2000))
        #expect(settings.dailyGoalValue == defaults.dailyHydrationGoal.amount.value)
        #expect(settings.dailyGoalUnitID == "milliliters")
        #expect(original.id == originalID)
        #expect(original.changedAt == Date(timeIntervalSince1970: 1000))
        #expect(original.goalValue == settings.dailyGoalValue)
        #expect(original.goalUnitID == settings.dailyGoalUnitID)
        #expect(original.source == HydrationGoalSource.appDefault.rawValue)
    }
    
    // MARK: - Test Helpers

    /// Writes an initial goal and one manual change to a supplied test store.
    ///
    /// Returns value identifiers rather than keeping the writing context or
    /// its model objects available to the test's verification step.
    ///
    /// - Returns: The history IDs ordered by change timestamp.
    /// - Throws: An error if creating, saving, or reading the store fails.
    /// - Parameter storeURL: The location of the disposable test store.
    private func writeGoalHistory(to storeURL: URL) throws -> [UUID] {
        let configuration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: Date(timeIntervalSince1970: 1000)
        )
        let newGoal = HydrationGoal(
            amount: DrinkAmount(value: 3000, unit: .milliliters)
        )
        let didChange = try AppSettingsPersistence.saveGoal(
            newGoal,
            source: .manual,
            settings: settings,
            in: context,
            at: Date(timeIntervalSince1970: 2000)
        )
        #expect(didChange)

        let history = try context.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>(
                sortBy: [SortDescriptor(\.changedAt)]
            )
        )
        return history.map { change in
            change.id
        }
    }
    
    /// Writes initial settings and a changed display unit to a disposable store.
    ///
    /// Keeps the writing container and context local to this helper.
    ///
    /// - Parameter storeURL: The location of the temporary test store.
    /// - Returns: The initial goal-history identifier for later verification.
    /// - Throws: An error if creating, saving, or reading the store fails.
    private func writeChangedDisplayUnit(to storeURL: URL) throws -> UUID {
        let configuration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: PersistentAppSettings.self,
            PersistentHydrationGoalChange.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let defaults = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        let settings = try AppSettingsPersistence.loadOrCreate(
            defaults: defaults,
            in: context,
            at: Date(timeIntervalSince1970: 1000)
        )
        let history = try context.fetch(
            FetchDescriptor<PersistentHydrationGoalChange>()
        )
        let originalID = try #require(history.first).id

        let didChange = try AppSettingsPersistence.saveDisplayUnit(
            .usFluidOunces,
            settings: settings,
            in: context,
            at: Date(timeIntervalSince1970: 2000)
        )
        #expect(didChange)

        return originalID
    }
}
