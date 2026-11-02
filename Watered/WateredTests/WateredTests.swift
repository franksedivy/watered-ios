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
        let entry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
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
        let entry = DrinkEntryFixture.make(
            drinkID: "latte",
            drinkName: "Coffee",
            hydrationRule: .ratio(0.99),
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

    // Given a decimal progress value, when it is formatted, then the string shows
    // a whole-number percentage.
    @Test func progressFormatterFormatsPercentage() {
        let formatter = ProgressFormatter()

        #expect(formatter.percentageString(from: 0.25) == "25%")
    }

}
