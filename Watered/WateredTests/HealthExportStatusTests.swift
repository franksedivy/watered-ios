import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct HealthExportStatusTests {
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

    @Test func fakeHealthScenarioRequiresIsolation() {
        #expect(AppLaunchConfiguration(arguments: ["-uiTestingHealth=denied"]).healthTestScenario == nil)
        #if DEBUG
        #expect(AppLaunchConfiguration(arguments: ["-uiTestingInMemory", "-uiTestingHealth=denied"]).healthTestScenario == "denied")
        #else
        #expect(AppLaunchConfiguration(arguments: ["-uiTestingInMemory", "-uiTestingHealth=denied"]).healthTestScenario == nil)
        #endif
    }
}
