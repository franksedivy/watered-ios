//
//  DrinkSubmissionHanlderTests.swift
//  Watered
//
//  Created by Frank Sedivy on 03/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkSubmissionHandlerTests {
    
    // GIVEN a form submission, when saving succeeds,
    // THEN the entry is saved once before state changes and exactly one form analytics event is
    // recorded.
    @Test func formSubmissionUpdatesStoreAndRecordsSuccess() throws {
        let store = WateredStore()
        let analytics = RecordingAnalyticsClient()
        let handler = DrinkSubmissionHandler(store: store, analytics: analytics)
        let entry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1_000)
        )
        var savedEntryIDs: [UUID] = []

        try handler.submit(
            entry,
            method: .form,
            save: { submittedEntry in
                #expect(store.entries.isEmpty)
                #expect(analytics.events.isEmpty)
                savedEntryIDs.append(submittedEntry.id)
            }
        )

        #expect(savedEntryIDs == [entry.id])
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.id == entry.id)
        #expect(analytics.events == [.drinkAdded(method: .form)])
    }
    
    // GIVEN a recent-drink submission, when saving succeeds,
    // then the entry is saved once before state changes and exactly one recent analytics event
    // is recorded.
    @Test func recentSubmissionUpdatesStoreAndRecordsSuccess() throws {
        let store = WateredStore()
        let analytics = RecordingAnalyticsClient()
        let handler = DrinkSubmissionHandler(store: store, analytics: analytics)
        let entry = DrinkEntry(
            type: .coffee,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1_000)
        )
        var savedEntryIDs: [UUID] = []

        try handler.submit(
            entry,
            method: .recent,
            save: { submittedEntry in
                #expect(store.entries.isEmpty)
                #expect(analytics.events.isEmpty)
                savedEntryIDs.append(submittedEntry.id)
            }
        )

        #expect(savedEntryIDs == [entry.id])
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.id == entry.id)
        #expect(analytics.events == [.drinkAdded(method: .recent)])
    }
    
    // GIVEN an existing drink, when saving a new submission fails,
    // THEN the error is propagated, existing state is preserved, and no event is recorded.
    @Test(arguments: [AddDrinkSubmissionMethod.form, .recent])
    func failedSubmissionPreservesStoreAndRecordsNoEvent(
        method: AddDrinkSubmissionMethod
    ) {
        let existingEntry = DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1_000)
        )
        let submittedEntry = DrinkEntry(
            type: .coffee,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 2_000)
        )
        let store = WateredStore(entries: [existingEntry])
        let analytics = RecordingAnalyticsClient()
        let handler = DrinkSubmissionHandler(store: store, analytics: analytics)
        var saveAttempts = 0

        do {
            try handler.submit(
                submittedEntry,
                method: method,
                save: { entry in
                    saveAttempts += 1
                    #expect(entry.id == submittedEntry.id)
                    throw TestSaveError.failed
                }
            )
            Issue.record("Submission should have thrown the save error.")
        } catch {
            #expect((error as? TestSaveError) == .failed)
        }

        #expect(saveAttempts == 1)
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.id == existingEntry.id)
        #expect(analytics.events.isEmpty)
    }
}

/// Collects analytics events in memory for test assertions.
@MainActor
private final class RecordingAnalyticsClient: AnalyticsClient {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

/// Provides a predictable save failure for submission tests.
private enum TestSaveError: Error, Equatable {
    case failed
}
