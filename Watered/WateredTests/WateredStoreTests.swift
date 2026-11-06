import Foundation
import Testing
@testable import Watered

@MainActor
struct WateredStoreTests {
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
        let entry = DrinkEntryFixture.make(
            drinkID: "test-tea",
            drinkName: "Tea",
            hydrationRule: .ratio(0.99),
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date()
        )
        
        let store = WateredStore()
        
        store.loadDrinkEntries([entry])
        
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.drinkID == "test-tea")
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
        
        let todayEntry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: today
        )
        let yesterdayEntry = DrinkEntryFixture.make(
            drinkID: "latte",
            drinkName: "Coffee",
            hydrationRule: .ratio(0.99),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: yesterday
        )
        
        let store = WateredStore(entries: [todayEntry, yesterdayEntry])
        
        let entries = store.drinkEntries(for: today, calendar: calendar)
        
        #expect(entries.count == 1)
        #expect(entries.first?.drinkID == "still-water")
    }
    
    // Given drink entries from yesterday only, when entries are filtered for
    // today, then no entries are returned.
    @MainActor
    @Test func wateredStoreExcludesPreviousCalendarDayDrinkEntries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = Date(timeIntervalSince1970: 1_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let yesterdayEntry = DrinkEntryFixture.make(
            drinkID: "latte",
            drinkName: "Coffee",
            hydrationRule: .ratio(0.99),
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
        let entry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date()
        )

        let store = WateredStore()

        store.addDrinkEntry(entry)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.drinkID == "still-water")
        #expect(store.entries.first?.amount.value == 330)
        #expect(store.entries.first?.amount.unit == .milliliters)
    }

    // Given an empty drink log, when recent drinks are requested,
    // then no shotcuts are returned
    @MainActor
    @Test func wateredStoreReturnsNoRecentDrinksForEmptyHistory() throws {
        let store = WateredStore()
        
        #expect(store.recentDrinkOptions(in: try DrinkCatalogueLoader().load()).isEmpty)
    }
    
    // Given unsorted history containing repeated water entries and newer coffee,
    // when recent drinks are requested, then coffee appears first and water
    // appears only once, with its original amount and unit preserved.
    @MainActor
    @Test func wateredStoreOrdersAndDeduplicatesRecentDrinks() throws {
        let olderWater = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date(timeIntervalSince1970: 100_000)
        )
        let newerWater = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date(timeIntervalSince1970: 200_000)
        )
        let catalogue = try DrinkCatalogueLoader().load()
        let coffee = try AddDrinkDraft(
            drinkID: "latte",
            volumeValue: 250,
            unit: .milliliters
        ).drinkEntry(
            using: DrinkCatalogueSnapshotResolver(catalogue: catalogue),
            date: Date(timeIntervalSince1970: 300_000)
        )
        let store = WateredStore(
            entries: [newerWater, coffee, olderWater]
        )
        
        let options = store.recentDrinkOptions(in: try DrinkCatalogueLoader().load())
        
        #expect(options.count == 2)
        #expect(options.first?.drinkID == "latte")
        #expect(options.first?.amount.value == 250)
        #expect(options.first?.amount.unit == .milliliters)
        #expect(options.last?.drinkID == "still-water")
        #expect(options.last?.amount.value == 300)
        #expect(options.last?.amount.unit == .milliliters)
    }
    
}
