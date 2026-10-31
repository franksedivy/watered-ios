//
//  WateredTests.swift
//  WateredTests
//
//  Created by Frank Sedivy on 26/06/2026.
//

import Foundation
import SwiftData
import Testing
@testable import Watered

struct WateredTests {

    // MARK: - DrinkAmount

    // Given a milliliter drink amount, when it is formatted, then it shows the
    // whole numeric value with Watered's milliliter unit label.
    @Test func drinkAmountFormatsMilliliters() {
        let amount = DrinkAmount(value: 250, unit: .milliliters)

        #expect(amount.formatted == "250 ml")
    }

    // Given a US fluid ounce drink amount, when it is formatted, then it shows
    // the whole numeric value with Watered's US fluid ounce unit label.
    @Test func drinkAmountFluidOunces() {
        let amount = DrinkAmount(value: 8, unit: .usFluidOunces)

        #expect(amount.formatted == "8 US fl oz")
    }

    // Given an imperial fluid ounce drink amount, when its measurement is converted
    // to milliliters, then Foundation returns the expected rounded milliliter value.
    @Test func drinkAmountConvertsImperialFluidOuncesToMilliliters() {
        let amount = DrinkAmount(value: 8, unit: .imperialFluidOunces)
        let volume = amount.volume.converted(to: .milliliters)

        #expect(Int(volume.value.rounded()) == 227)
    }

    // Given a drink amount, when its description is read, then the description
    // matches the formatted amount used by simple labels and logs.
    @Test func drinkAmountDescriptionUsesFormattedAmount() {
        let amount = DrinkAmount(value: 250, unit: .milliliters)

        #expect(amount.description == "250 ml")
    }

    // MARK: - DrinkType

    // Given the water drink type, when its hydration rule is read, then Watered
    // treats the full consumed volume as hydration.
    @Test func drinkTypeWaterUsesFullHydrationContributionRatio() {
        #expect(DrinkType.water.hydrationContributionRule == HydrationContributionRule.ratio(1.0))
    }

    // Given the tea drink type, when its hydration rule is read, then Watered
    // uses the estimated tea hydration contribution ratio.
    @Test func drinkTypeTeaUsesEstimatedHydrationContributionRatio() {
        #expect(DrinkType.tea.hydrationContributionRule == HydrationContributionRule.ratio(0.99))
    }

    // Given the juice drink type, when its hydration rule is read, then Watered
    // uses the estimated juice hydration contribution ratio.
    @Test func drinkTypeJuiceUsesEstimatedHydrationContributionRatio() {
        #expect(DrinkType.juice.hydrationContributionRule == HydrationContributionRule.ratio(0.89))
    }

    // Given the coffee drink type, when its hydration rule is read, then Watered
    // uses the estimated coffee hydration contribution ratio.
    @Test func drinkTypeCoffeeUsesEstimatedHydrationContributionRatio() {
        #expect(DrinkType.coffee.hydrationContributionRule == HydrationContributionRule.ratio(0.99))
    }

    // Given the beer drink type, when its hydration rule is read, then Watered
    // uses the shared default alcohol rule for beer.
    @Test func drinkTypeBeerUsesDefaultAlcoholRule() {
        #expect(DrinkType.beer.hydrationContributionRule == HydrationContributionRule.alcohol(defaultABV: 0.05))
    }

    // Given the cider drink type, when its hydration rule is read, then Watered
    // uses the shared default alcohol rule for cider.
    @Test func drinkTypeCiderUsesDefaultAlcoholRule() {
        #expect(DrinkType.cider.hydrationContributionRule == HydrationContributionRule.alcohol(defaultABV: 0.05))
    }

    // Given the wine drink type, when its hydration rule is read, then Watered
    // uses the default wine alcohol rule.
    @Test func drinkTypeWineUsesDefaultAlcoholRule() {
        #expect(DrinkType.wine.hydrationContributionRule == HydrationContributionRule.alcohol(defaultABV: 0.13))
    }

    // Given the spirits drink type, when its hydration rule is read, then Watered
    // uses the default spirits alcohol rule.
    @Test func drinkTypeSpiritsUsesDefaultAlcoholRule() {
        #expect(DrinkType.spirits.hydrationContributionRule == HydrationContributionRule.alcohol(defaultABV: 0.40))
    }

    // Given the other drink type, when its hydration rule is read, then Watered
    // keeps the hydration contribution unknown rather than guessing.
    @Test func drinkTypeOtherUsesUnknownHydrationContributionRule() {
        #expect(DrinkType.other.hydrationContributionRule == HydrationContributionRule.unknown)
    }

    // MARK: - DrinkEntry

    // Given explicit type, amount, and date values, when a drink entry is created,
    // then the entry stores those values unchanged.
    @Test func drinkEntryStoresTypeAmountAndDate() {
        let date = Date()
        let amount = DrinkAmount(value: 250, unit: .milliliters)

        let entry = DrinkEntry(
            type: .water,
            amount: amount,
            date: date
        )

        #expect(entry.type == .water)
        #expect(entry.amount.formatted == "250 ml")
        #expect(entry.date == date)
    }

    // Given a drink entry created without explicit persistence metadata,
    // when the entry is initialised, then it receives default metadata ready
    // for persistence.
    @Test func drinkEntryCreatesManualMetadataByDefault() {
        let loggedDate = Date()
        let entry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: loggedDate
        )

        #expect(entry.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(entry.loggedAt == loggedDate)
        #expect(entry.source == .manual)
        #expect(entry.createdAt <= Date())
        #expect(entry.updatedAt <= Date())
    }

    // Given two drink entries created without explicit identifiers, when their
    // IDs are compared, then each entry has a distinct identifier for persistence.
    @Test func drinkEntryCreatesDifferentIdentifiersByDefault() {
        let firstEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let secondEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        #expect(firstEntry.id != secondEntry.id)
    }

    // Given explicit metadata values from persistence, when a drink entry is
    // recreated, then the model preserves the metadata exactly.
    @Test func drinkEntryAcceptsExplicitPersistenceMetadata() {
        let id = UUID()
        let loggedDate = Date(timeIntervalSince1970: 1000)
        let createdAt = Date(timeIntervalSince1970: 2000)
        let updatedAt = Date(timeIntervalSince1970: 3000)

        let entry = DrinkEntry(
            id: id,
            type: .coffee,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: loggedDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: .manual,
        )

        #expect(entry.id == id)
        #expect(entry.date == loggedDate)
        #expect(entry.loggedAt == loggedDate)
        #expect(entry.createdAt == createdAt)
        #expect(entry.updatedAt == updatedAt)
        #expect(entry.source == .manual)
    }

    // Given a drink entry, when its description is read, then it includes the
    // user-facing drink type and formatted amount.
    @Test func drinkEntryDescriptionIncludesTypeAndAmount() {
        let entry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        #expect(entry.description == "Water, 250 ml")
    }

    // Given a water drink entry, when its hydration contribution is calculated,
    // then the full consumed water volume counts toward hydration.
    @Test func drinkEntryHydrationContributionVolumeKeepsFullWaterAmount() {
        let entry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == 250)
    }

    // Given a juice drink entry, when its hydration contribution is calculated,
    // then the contribution uses the juice hydration ratio.
    @Test func drinkEntryJuiceHydrationContributionVolumeUsesHydrationContributionRatio() {
        let entry = DrinkEntry(
            type: .juice,
            amount: DrinkAmount(value: 100, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == 89)
    }

    // Given an other drink entry, when its hydration contribution is requested,
    // then Watered returns nil because the contribution is unknown.
    @Test func drinkEntryOtherHydrationContributionVolumeIsUnknown() {
        let entry = DrinkEntry(
            type: .other,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        #expect(entry.hydrationContributionVolume == nil)
    }

    // Given a beer drink entry, when its hydration contribution is calculated,
    // then the contribution remains positive but lower than the consumed volume.
    @Test func drinkEntryBeerHydrationContributionIsPositiveButReduced() {
        let entry = DrinkEntry(
            type: .beer,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == 165)
    }

    // Given a spirits drink entry, when its hydration contribution is calculated,
    // then the alcohol rule produces a negative hydration contribution.
    @Test func drinkEntrySpiritsHydrationContributionIsNegative() {
        let entry = DrinkEntry(
            type: .spirits,
            amount: DrinkAmount(value: 25, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == -75)
    }

    // Given a wine drink entry, when its hydration contribution is calculated,
    // then the alcohol rule produces a negative hydration contribution.
    @Test func drinkEntryWineHydrationContributionIsNegative() {
        let entry = DrinkEntry(
            type: .wine,
            amount: DrinkAmount(value: 150, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == -45)
    }

    // MARK: - AddDrinkDraft

    // Given selected Add Drink form values and an explicit date, when the draft
    // creates a drink entry, then the entry contains the selected values and date.
    @Test func addDrinkDraftCreatesDrinkEntryFromSelectedValues() {
        let date = Date()

        let draft = AddDrinkDraft(
            drinkType: .water,
            volumeValue: 330,
            unit: .milliliters
        )

        let entry = draft.drinkEntry(date: date)

        #expect(entry.type == .water)
        #expect(entry.amount.value == 330)
        #expect(entry.amount.unit == .milliliters)
        #expect(entry.date == date)
    }

    // Given selected Add Drink form values using imperial units, when the draft
    // creates a drink entry, then the selected unit is preserved.
    @Test func addDrinkDraftPreservesSelectedUnitWhenCreatingDrinkEntry() {
        let draft = AddDrinkDraft(
            drinkType: .coffee,
            volumeValue: 8,
            unit: .imperialFluidOunces
        )

        let entry = draft.drinkEntry()

        #expect(entry.type == .coffee)
        #expect(entry.amount.value == 8)
        #expect(entry.amount.unit == .imperialFluidOunces)
    }
    
    // MARK: - PersistentDrinkEntry
    //
    // Given a drink entry with persistence metadata, when a persistent drink entry
    // is created from it, then the stored values use stable persistence identifiers.
    @MainActor
    @Test func persistentDrinkEntryStoresDrinkEntryValues() {
        let id = UUID()
        let loggedAt = Date(timeIntervalSince1970: 1000)
        let createdAt = Date(timeIntervalSince1970: 2000)
        let updatedAt = Date(timeIntervalSince1970: 3000)

        let drinkEntry = DrinkEntry(
            id: id,
            type: .coffee,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: loggedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: .manual
        )

        let persistentDrinkEntry = PersistentDrinkEntry(drinkEntry: drinkEntry)

        #expect(persistentDrinkEntry.id == id)
        #expect(persistentDrinkEntry.drinkTypeID == "coffee")
        #expect(persistentDrinkEntry.volumeValue == 250)
        #expect(persistentDrinkEntry.unitID == "milliliters")
        #expect(persistentDrinkEntry.loggedAt == loggedAt)
        #expect(persistentDrinkEntry.createdAt == createdAt)
        #expect(persistentDrinkEntry.updatedAt == updatedAt)
        #expect(persistentDrinkEntry.source == "manual")
    }

    // Given a persistent drink entry with known stored identifiers, when it is
    // converted back to the app model, then it creates the matching DrinkEntry.
    @MainActor
    @Test func persistentDrinkEntryCreatesDrinkEntryFromStoredValues() throws {
        let id = UUID()
        let loggedAt = Date(timeIntervalSince1970: 1000)
        let createdAt = Date(timeIntervalSince1970: 2000)
        let updatedAt = Date(timeIntervalSince1970: 3000)

        let persistentDrinkEntry = PersistentDrinkEntry(
            id: id,
            drinkTypeID: "tea",
            volumeValue: 300,
            unitID: "imperialFluidOunces",
            loggedAt: loggedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: "manual"
        )

        let drinkEntry = try #require(persistentDrinkEntry.drinkEntry())

        #expect(drinkEntry.id == id)
        #expect(drinkEntry.type == .tea)
        #expect(drinkEntry.amount.value == 300)
        #expect(drinkEntry.amount.unit == .imperialFluidOunces)
        #expect(drinkEntry.loggedAt == loggedAt)
        #expect(drinkEntry.createdAt == createdAt)
        #expect(drinkEntry.updatedAt == updatedAt)
        #expect(drinkEntry.source == .manual)
    }

    // Given a persistent drink entry with an unknown drink type identifier, when it
    // is converted back to the app model, then Watered refuses to guess the type.
    @MainActor
    @Test func persistentDrinkEntryReturnsNilForUnknownDrinkTypeID() {
        let persistentDrinkEntry = PersistentDrinkEntry(
            id: UUID(),
            drinkTypeID: "soda",
            volumeValue: 300,
            unitID: "milliliters",
            loggedAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            source: "manual"
        )

        #expect(persistentDrinkEntry.drinkEntry() == nil)
    }
    
    // MARK: - Hydration Goal History
    //
    // GIVEN a committed goal change, when it is mapped into a persistent record and back,
    // THEN its identitiy, amount, unit, timestamp, and source are preserved.
    @MainActor
    @Test func persistentHydrationGoalChangePreservesRecordedValues() throws {
        let id = UUID()
        let changedAt = Date(timeIntervalSince1970: 1000)
        let change = HydrationGoalChange(
            id: id,
            goal: HydrationGoal(
                amount: DrinkAmount(value: 90, unit: .usFluidOunces)
            ),
            changedAt: changedAt,
            source: .manual
        )
        
        let storedChange = PersistentHydrationGoalChange(change: change)
        
        #expect(storedChange.id == id)
        #expect(storedChange.goalValue == 90)
        #expect(storedChange.goalUnitID == "usFluidOunces")
        #expect(storedChange.changedAt == changedAt)
        #expect(storedChange.source == "manual")
        
        let restoredChange = try #require(storedChange.hydrationGoalChange())
        
        #expect(restoredChange.id == id)
        #expect(restoredChange.goal.amount.value == 90)
        #expect(restoredChange.goal.amount.unit == .usFluidOunces)
        #expect(restoredChange.changedAt == changedAt)
        #expect(restoredChange.source == .manual)
    }
    
    // GIVEN a stored goal change with an unknown unit identifier, when it is reconstructed,
    // THEN the mapper returns nil rather than interpreting the amount using a guessed unit.
    @MainActor
    @Test func persistentHydrationGoalChangesRejectsUnknownUnit() {
        let change = HydrationGoalChange(
            goal: HydrationGoal(
                amount: DrinkAmount(value: 2700, unit: .milliliters)
            ),
            changedAt: Date(timeIntervalSince1970: 1000),
            source: .manual
        )
        let storedChange = PersistentHydrationGoalChange(change: change)
        storedChange.goalUnitID = "uknown-unit"
        
        #expect(storedChange.hydrationGoalChange() == nil)
    }
    
    // GIVEN a stored goal change with an unknown source identifier, when it is reconstrcuted,
    // THEN the mapper returns nil rather than incorrectly attributing the change.
    @MainActor
    @Test func persistentHydrationGoalChangeRejectsUnknownSource() {
        let change = HydrationGoalChange(
            goal: HydrationGoal(
                amount: DrinkAmount(value: 2700, unit: .milliliters)
            ),
            changedAt: Date(timeIntervalSince1970: 1000),
            source: .manual
        )
        let storedChange = PersistentHydrationGoalChange(change: change)
        storedChange.source = "unknown-source"
        
        #expect(storedChange.hydrationGoalChange() == nil)
    }
    
    // MARK: - AppSettings
    //
    // Given a US locale, when Watered creates first-run app settings, then the
    // display unit defaults to US fluid ounces.
    @Test func appSettingsDefaultsToUSFluidOuncesForUSLocale() {
        let settings = AppSettings.defaults(for: Locale(identifier: "en_US"))
        
        #expect(settings.displayUnit == .usFluidOunces)
        #expect(settings.dailyHydrationGoal.amount.value == 2700)
        #expect(settings.dailyHydrationGoal.amount.unit == .milliliters)
    }
    
    // Given a UK locale, when Watered creates first-run app settings, then the
    // display unit still defaults to milliliters rather than imperial fluid ounces.
    @Test func appSettingsDefaultsToMillilitersForUKLocale() {
        let settings = AppSettings.defaults(for: Locale(identifier: "en_GB"))
        
        #expect(settings.displayUnit == .milliliters)
        #expect(settings.dailyHydrationGoal.amount.value == 2700)
        #expect(settings.dailyHydrationGoal.amount.unit == .milliliters)
    }
    
    // Given a metric locale, when Watered creates first-run app settings, then the
    // display unit defaults to milliliters.
    @Test func appSettingsDefaultsToMillilitersForMetricLocale() {
        let settings = AppSettings.defaults(for: Locale(identifier: "es_ES"))
        
        #expect(settings.displayUnit == .milliliters)
        #expect(settings.dailyHydrationGoal.amount.value == 2700)
        #expect(settings.dailyHydrationGoal.amount.unit == .milliliters)
    }
    
    // MARK: - PersistentAppSettings
    //
    // Given app settings with a display unit and hydration goal, when persistent
    // settings are created, then SwiftData stores stable identifiers and values.
    @MainActor
    @Test func persistentAppSettingsStoresAppSettingsValues() {
        let appSettings = AppSettings(
            displayUnit: .usFluidOunces,
            dailyHydrationGoal: HydrationGoal(
                amount: DrinkAmount(value: 90, unit: .usFluidOunces)
            )
        )
        
        let persistentSettings = PersistentAppSettings(appSettings: appSettings)
        
        #expect(persistentSettings.id == "appSettings")
        #expect(persistentSettings.displayUnitID == "usFluidOunces")
        #expect(persistentSettings.dailyGoalValue == 90)
        #expect(persistentSettings.dailyGoalUnitID == "usFluidOunces")
        #expect(persistentSettings.createdAt <= Date())
        #expect(persistentSettings.updatedAt <= Date())
    }
    
    // Given persistent settings with known stored identifiers, when they are
    // converted back to the app model, then Watered recreates matching settings.
    @MainActor
    @Test func persistentAppSettingsCreatesAppSettingsFromStoredValues() throws {
        let persistentSettings = PersistentAppSettings(
            displayUnitID: "milliliters",
            dailyGoalValue: 2700,
            dailyGoalUnitID: "milliliters",
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000)
        )
        
        let appSettings = try #require(persistentSettings.appSettings())
        
        #expect(appSettings.displayUnit == .milliliters)
        #expect(appSettings.dailyHydrationGoal.amount.value == 2700)
        #expect(appSettings.dailyHydrationGoal.amount.unit == .milliliters)
    }
    
    // Given persistent settings with an unknown display unit identifier, when they
    // are converted back to the app model, then Watered refuses to guess settings.
    @MainActor
    @Test func persistentAppSettingsReturnsNilForUnknownDisplayUnitID() {
        let persistentSettings = PersistentAppSettings(
            displayUnitID: "cups",
            dailyGoalValue: 2700,
            dailyGoalUnitID: "milliliters"
        )
        
        #expect(persistentSettings.appSettings() == nil)
    }
    
    // Given persistent settings with an unknown daily goal unit identifier, when
    // they are converted back to the app model, then Watered refuses to guess
    // settings.
    @MainActor
    @Test func persistentAppSettingsReturnsNilForUnknownDailyGoalUnitID() {
        let persistentSettings = PersistentAppSettings(
            displayUnitID: "milliliters",
            dailyGoalValue: 2700,
            dailyGoalUnitID: "cups"
        )
        
        #expect(persistentSettings.appSettings() == nil)
    }

    // MARK: - TodayCalendarDay
    //
    // Given an active Today calendar day, when a drink entry was logged on the
    // same local calendar day, then the entry belongs to Today.
    @Test func todayCalendarDayContainsEntryFromSameCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = Date(timeIntervalSince1970: 1_000_000)
        let laterToday = today.addingTimeInterval(60 * 60)
        
        let activeDay = TodayCalendarDay(date: today, calendar: calendar)
        let entry = DrinkEntry(
            type: .water,
            amount: .init(value: 300, unit: .milliliters),
            date: laterToday
        )
        
        #expect(activeDay.contains(entry))
    }
    
    // Given an active Today calendar day, when a drink entry was logged on the
    // previous local calendar day, then the entry does not belong to Today.
    @Test func todayCalendarDayExcludesEntryFromPreviousCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = Date(timeIntervalSince1970: 1_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let activeDay = TodayCalendarDay(date: today, calendar: calendar)
        let entry = DrinkEntry(
            type: .coffee,
            amount: .init(value: 250, unit: .milliliters),
            date: yesterday
        )
        
        #expect(activeDay.contains(entry) == false)
    }
    
    // Given an active Today calendar day, when it is refreshed with a new date,
    // then it stores the new date for future Today filtering.
    @Test func todayCalendarDayRefreshesActiveDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let previousDay = Date(timeIntervalSince1970: 1_000_000)
        let nextDay = previousDay.addingTimeInterval(60 * 60 * 24)
        
        var activeDay = TodayCalendarDay(date: previousDay, calendar: calendar)
        
        activeDay.refresh(now: nextDay)
        
        #expect(activeDay.date == nextDay)
    }
    
    // MARK: - WateredStore

    // Given a new WateredStore, when its entries are read, then it starts with
    // an empty drink log.
    @MainActor
    @Test func wateredStoresStartsWithoutNoDrinkEntries() {
        let store = WateredStore()

        #expect(store.entries.isEmpty)
    }
    
    // Given persisted drink entries recreated from storage, when they are loaded
    // into WateredStore, then the store exposes them as its current drink log.
    @MainActor
    @Test func wateredStoreLoadsPersistedDrinkEntries() {
        let entry = DrinkEntry(
            type: .tea,
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date()
        )
        
        let store = WateredStore()
        
        store.loadDrinkEntries([entry])
        
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.type == .tea)
        #expect(store.entries.first?.amount.value == 300)
        #expect(store.entries.first?.amount.unit == .milliliters)
    }
    
    // Given drink entries from today and yesterday, when entries are filtered for
    // today, then only today's entries are returned.
    @MainActor
    @Test func wateredStoreReturnsDrinkEntriesForCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = Date(timeIntervalSince1970: 1_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let todayEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: today
        )
        let yesterdayEntry = DrinkEntry(
            type: .coffee,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: yesterday
        )
        
        let store = WateredStore(entries: [todayEntry, yesterdayEntry])
        
        let entries = store.drinkEntries(for: today, calendar: calendar)
        
        #expect(entries.count == 1)
        #expect(entries.first?.type == .water)
    }
    
    // Given drink entries from yesterday only, when entries are filtered for
    // today, then no entries are returned.
    @MainActor
    @Test func wateredStoreExcludesPreviousCalendarDayDrinkEntries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = Date(timeIntervalSince1970: 1_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let yesterdayEntry = DrinkEntry(
            type: .coffee,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: yesterday
        )
        
        let store = WateredStore(entries: [yesterdayEntry])
        
        let entries = store.drinkEntries(for: today, calendar: calendar)
        
        #expect(entries.isEmpty)
    }

    // Given a drink entry and an empty WateredStore, when the entry is added,
    // then the store exposes the new entry through its app-level state.
    @MainActor
    @Test func wateredStoredAddsDrinkEntry() {
        let entry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date()
        )

        let store = WateredStore()

        store.addDrinkEntry(entry)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.type == .water)
        #expect(store.entries.first?.amount.value == 330)
        #expect(store.entries.first?.amount.unit == .milliliters)
    }

    // Given an empty drink log, when recent drinks are requested,
    // then no shotcuts are returned
    @MainActor
    @Test func wateredStoreReturnsNoRecentDrinksForEmptyHistory() {
        let store = WateredStore()
        
        #expect(store.recentDrinkOptions.isEmpty)
    }
    
    // Given unsorted history containing repeated water entries and newer coffee,
    // when recent drinks are requested, then coffee appears first and water
    // appears only once, with its original amount and unit preserved.
    @MainActor
    @Test func wateredStoreOrdersAndDeduplicatesRecentDrinks() {
        let olderWater = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date(timeIntervalSince1970: 100_000)
        )
        let newerWater = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date(timeIntervalSince1970: 200_000)
        )
        let coffee = DrinkEntry(
            type: .coffee,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 300_000)
        )
        let store = WateredStore(
            entries: [newerWater, coffee, olderWater]
        )
        
        let options = store.recentDrinkOptions
        
        #expect(options.count == 2)
        #expect(options.first?.drinkType == .coffee)
        #expect(options.first?.volumeValue == 250)
        #expect(options.first?.unit == .milliliters)
        #expect(options.last?.drinkType == .water)
        #expect(options.last?.volumeValue == 300)
        #expect(options.last?.unit == .milliliters)
    }
    
    // MARK: - HydrationSnapshot

    // Given known hydration and goal volumes, when snapshot progress is read,
    // then actual and visual progress use the same in-range value.
    @Test func hydrationSnapshotCalculatesHydrationProgress() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 100, unit: UnitVolume.milliliters),
            totalHydrationVolume: Measurement(value: 89, unit: UnitVolume.milliliters),
            goalVolume: Measurement(value: 200, unit: UnitVolume.milliliters),
            remainingHydrationVolume: Measurement(value: 111, unit: UnitVolume.milliliters),
            drinkBreakdown: []
        )

        #expect(snapshot.hydrationProgress == 0.445)
        #expect(snapshot.clampedHydrationProgress == 0.445)
    }

    // Given an unknown hydration contribution, when snapshot progress is read,
    // then both actual and visual hydration progress remain unknown.
    @Test func hydrationSnapshotHydrationProgressIsUnknownWhenHydrationContributionVolumeIsUnknown() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 100, unit: UnitVolume.milliliters),
            totalHydrationVolume: nil,
            goalVolume: Measurement(value: 200, unit: UnitVolume.milliliters),
            remainingHydrationVolume: nil,
            drinkBreakdown: []
        )

        #expect(snapshot.hydrationProgress == nil)
        #expect(snapshot.clampedHydrationProgress == nil)
    }

    // Given a negative hydration contribution, when snapshot progress is read,
    // then actual progress stays negative while visual progress clamps to zero.
    @Test func hydrationSnapshotKeepsActualNegativeProgressButClampsVisualProgress() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 25, unit: UnitVolume.milliliters),
            totalHydrationVolume: Measurement(value: -75, unit: UnitVolume.milliliters),
            goalVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            remainingHydrationVolume: Measurement(value: 2075, unit: UnitVolume.milliliters),
            drinkBreakdown: []
        )

        #expect(snapshot.hydrationProgress == -0.0375)
        #expect(snapshot.clampedHydrationProgress == 0)
    }

    // Given hydration above the daily goal, when snapshot progress is read, then
    // actual progress stays above one while visual progress clamps to one.
    @Test func hydrationSnapshotKeepsActualProgressAboveOne() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 2500, unit: UnitVolume.milliliters),
            totalHydrationVolume: Measurement(value: 2500, unit: UnitVolume.milliliters),
            goalVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            remainingHydrationVolume: Measurement(value: 0, unit: UnitVolume.milliliters),
            drinkBreakdown: []
        )

        #expect(snapshot.hydrationProgress == 1.25)
        #expect(snapshot.clampedHydrationProgress == 1)
    }

    // MARK: - VolumeCalculation

    // Given a Foundation volume measurement, when it is converted to Watered's
    // base value, then the result is stored in milliliters.
    @Test func volumeCalculationConvertsMeasurementToBaseValue() {
        let volume = Measurement(value: 1, unit: UnitVolume.liters)

        #expect(VolumeCalculation.baseValue(from: volume) == 1000)
    }

    // Given a Watered base volume value, when it is converted to a measurement,
    // then the result uses Watered's base milliliter unit.
    @Test func volumeCalculationCreatesMeasurementFromBaseValue() {
        let volume = VolumeCalculation.measurement(fromBaseValue: 750)

        #expect(volume.value == 750)
        #expect(volume.unit == VolumeCalculation.baseUnit)
    }

    // MARK: - Formatters

    // Given a volume and milliliter display unit, when it is formatted, then the
    // string shows the whole-number milliliter value.
    @Test func volumeFormatterFormatsWholeMilliliters() {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let volume = Measurement(value: 1000, unit: UnitVolume.milliliters)

        #expect(formatter.wholeNumberString(from: volume, displayedAs: .milliliters) == "1000 ml")
    }

    // Given a milliliter volume and US fluid ounce display unit, when it is
    // formatted, then the string shows the rounded US fluid ounce value.
    @Test func volumeFormatterFormatsWholeUSFluidOunces() {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let volume = Measurement(value: 1000, unit: UnitVolume.milliliters)

        #expect(formatter.wholeNumberString(from: volume, displayedAs: .usFluidOunces) == "34 US fl oz")
    }

    // Given a milliliter volume and imperial fluid ounce display unit, when it is
    // formatted, then the string shows the rounded imperial fluid ounce value.
    @Test func volumeFormatterFormatsWholeImperialFluidOunces() {
        let formatter = VolumeFormatter(locale: Locale(identifier: "en_GB"))
        let volume = Measurement(value: 1000, unit: UnitVolume.milliliters)

        #expect(formatter.wholeNumberString(from: volume, displayedAs: .imperialFluidOunces) == "35 fl oz")
    }

    // Given a decimal progress value, when it is formatted, then the string shows
    // a whole-number percentage.
    @Test func progressFormatterFormatsPercentage() {
        let formatter = ProgressFormatter()

        #expect(formatter.percentageString(from: 0.25) == "25%")
    }

}
