import Foundation
import SwiftData
import Testing
@testable import Watered

/// Verifies presentation boundaries using synthetic records and an isolated store.
@MainActor
struct HealthExportStatusTests {
    // Given mixed upload and deletion work, each type keeps independent outcomes and
    // disabling sync changes pending wording without losing sent acknowledgements.
    @Test func independentOutcomesExcludeCleanupAndPreserveSentWhileDisabled() {
        func record(_ type: HealthWriteType, _ status: String, operation: String = "upload", failure: String? = nil) -> PersistentHealthExport {
            let record = PersistentHealthExport(entryID: UUID(), type: type, payload: nil)
            record.status = status
            record.operation = operation
            record.failureCategory = failure
            return record
        }
        let records = [record(.water, "succeeded"), record(.water, "pending"),
                       record(.water, "inFlight"), record(.water, "authorizationBlocked"),
                       record(.water, "pending", failure: "temporary"), record(.water, "invalid"),
                       record(.water, "succeeded", operation: "delete"), record(.caffeine, "succeeded")]
        let water = HealthExportStatus(records: records, type: .water)
        #expect(water.sent == 1)
        #expect(water.pending == 2)
        #expect(water.blocked == 1)
        #expect(water.failed == 1)
        #expect(water.invalid == 1)
        #expect(water.message(enabled: false).contains("Sent to Apple Health: 1"))
        #expect(water.message(enabled: false).contains("Paused: 2"))
        #expect(water.message(enabled: false).contains("Retry paused: 1"))
        #expect(water.message(enabled: true).contains("Waiting to retry: 1"))
        #expect(HealthExportStatus(records: records, type: .alcohol).message(enabled: true) == "No eligible exports")
    }

    // Given a failed preference transaction, both opt-in and opt-out preserve the last
    // committed choice and neither path requests system permission.
    @Test func failedPreferenceCommitPreservesOptInAndDoesNotRequestPermission() throws {
        enum Failure: Error { case save }
        let schema = Schema([PersistentDrinkEntry.self, PersistentHealthExport.self, PersistentHealthSyncPreference.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let client = FakeHealthKitClient(statuses: [.water: .authorized])
        let coordinator = HealthExportCoordinator(client: client, beforeSave: { throw Failure.save })
        coordinator.attach(to: container)
        #expect(throws: Failure.self) { try coordinator.setEnabled(true) }
        #expect(try !HealthExportPersistence.isEnabled(in: ModelContext(container)))
        try HealthExportPersistence.setEnabled(true, in: ModelContext(container), at: Date())
        #expect(throws: Failure.self) { try coordinator.setEnabled(false) }
        #expect(try HealthExportPersistence.isEnabled(in: ModelContext(container)))
        #expect(client.requestCount == 0)
    }

    // Only committed off-to-on actions count, even when every Health type is unavailable.
    // Repeated on, disabling and permission state must not create extra enablement events.
    @Test func enablementAnalyticsFollowCommittedTransitionsOnly() throws {
        let schema = Schema([PersistentDrinkEntry.self, PersistentHealthExport.self, PersistentHealthSyncPreference.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let coordinator = HealthExportCoordinator(client: FakeHealthKitClient())
        coordinator.attach(to: container)
        let analytics = HealthPreferenceAnalyticsRecorder()
        var savedPreferences: [Bool?] = []
        analytics.onTrack = {
            savedPreferences.append(try? HealthExportPersistence.isEnabled(in: ModelContext(container)))
        }
        try coordinator.setEnabled(false, analytics: analytics)
        try coordinator.setEnabled(true, analytics: analytics)
        try coordinator.setEnabled(true, analytics: analytics)
        try coordinator.setEnabled(false, analytics: analytics)
        #expect(analytics.events == [.appleHealthSyncEnabled])
        try coordinator.setEnabled(true, analytics: analytics)
        #expect(analytics.events == [.appleHealthSyncEnabled, .appleHealthSyncEnabled])
        #expect(savedPreferences == [true, true])
    }

    // A failed enablement cannot count as adoption; a successful retry reports once,
    // after a separate context can observe the saved preference.
    @Test func failedEnablementEmitsNothingAndSuccessfulRetryEmitsOnce() throws {
        enum Failure: Error { case save }
        let schema = Schema([PersistentDrinkEntry.self, PersistentHealthExport.self, PersistentHealthSyncPreference.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        var shouldFail = true
        let coordinator = HealthExportCoordinator(client: FakeHealthKitClient(), beforeSave: {
            if shouldFail { throw Failure.save }
        })
        coordinator.attach(to: container)
        let analytics = HealthPreferenceAnalyticsRecorder()
        #expect(throws: Failure.self) { try coordinator.setEnabled(true, analytics: analytics) }
        #expect(analytics.events.isEmpty)
        #expect(try !HealthExportPersistence.isEnabled(in: ModelContext(container)))
        shouldFail = false
        try coordinator.setEnabled(true, analytics: analytics)
        #expect(analytics.events == [.appleHealthSyncEnabled])
    }

    // A pass with no suspension must still invalidate presentation, even when SwiftUI
    // observes isProcessing as false both before and after the worker runs.
    @Test func completedPassAdvancesPresentationRevision() async throws {
        let schema = Schema([PersistentDrinkEntry.self, PersistentHealthExport.self, PersistentHealthSyncPreference.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let coordinator = HealthExportCoordinator(client: FakeHealthKitClient())
        coordinator.attach(to: container)
        let revision = coordinator.progressRevision
        await coordinator.process()
        #expect(coordinator.progressRevision > revision)
        #expect(!coordinator.isProcessing)
    }

    // Permission fixtures require isolated Debug storage and cannot alter normal launches.
    @Test func fakeHealthScenarioRequiresIsolation() {
        #expect(AppLaunchConfiguration(arguments: ["-uiTestingHealth=denied"]).healthTestScenario == nil)
        #if DEBUG
        #expect(AppLaunchConfiguration(arguments: ["-uiTestingInMemory", "-uiTestingHealth=denied"]).healthTestScenario == "denied")
        #else
        #expect(AppLaunchConfiguration(arguments: ["-uiTestingInMemory", "-uiTestingHealth=denied"]).healthTestScenario == nil)
        #endif
    }
}

/// Captures typed interaction events in tests; no logger or production transport is involved.
@MainActor
private final class HealthPreferenceAnalyticsRecorder: AnalyticsClient {
    var events: [AnalyticsEvent] = []
    var onTrack: (() -> Void)?

    func track(_ event: AnalyticsEvent) {
        events.append(event)
        onTrack?()
    }
}
