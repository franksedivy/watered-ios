import Foundation
import HealthKit
import SwiftData
import Testing
@testable import Watered

@MainActor
struct HealthExportTests {
    private let date = Date(timeIntervalSince1970: 1_794_686_400)

    private func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([PersistentDrinkEntry.self, PersistentHealthExport.self, PersistentHealthSyncPreference.self])
        let configuration = url.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func entry(water: Double? = 170, caffeine: Double? = 40, abv: Double? = 0.1) -> DrinkEntry {
        DrinkEntry(amount: .init(value: 200, unit: .milliliters), date: date, createdAt: date.addingTimeInterval(3600),
            catalogueSnapshot: .init(drinkID: "synthetic", drinkName: "Synthetic", caffeineVariant: .regular,
                shotCount: nil, hydrationContribution: 0, caffeineAmount: caffeine,
                catalogueVersion: "original", calculationVersion: "original", catalogueSchemaVersion: 6,
                waterAmount: water, alcoholABV: abv))
    }

    private func records(_ container: ModelContainer) throws -> [PersistentHealthExport] {
        try ModelContext(container).fetch(FetchDescriptor<PersistentHealthExport>())
    }

    private func save(_ entry: DrinkEntry, in container: ModelContainer, client: TestExportClient) throws {
        try DrinkEntryPersistence.save(entry, in: ModelContext(container), healthClient: client)
    }

    private func enable(_ container: ModelContainer, _ enabled: Bool = true) throws {
        try HealthExportPersistence.setEnabled(enabled, in: ModelContext(container), at: date)
    }

    private func worker(_ container: ModelContainer, client: TestExportClient,
                        beforeSave: @escaping () throws -> Void = {}) -> HealthExportCoordinator {
        let worker = HealthExportCoordinator(client: client, now: { date }, jitter: { 1 }, beforeSave: beforeSave)
        worker.attach(to: container)
        return worker
    }

    @Test func creationBoundaryBackdatingDisabledGapAndNewGrants() async throws {
        let container = try container()
        let client = TestExportClient()
        try save(entry(), in: container, client: client) // absent preference is off
        try enable(container)
        client.statuses[.caffeine] = .denied
        client.statuses[.alcohol] = .notDetermined
        let eligible = entry()
        try save(eligible, in: container, client: client)
        try enable(container, false)
        try save(entry(), in: container, client: client)
        let worker = worker(container, client: client)
        await worker.process()
        #expect(client.writes.isEmpty)
        client.statuses = Dictionary(uniqueKeysWithValues: HealthWriteType.allCases.map { ($0, .authorized) })
        try enable(container)
        await worker.process()
        #expect(client.writes.count == 1)
        #expect(client.writes.first?.type == .water)
        #expect(client.writes.first?.entryID == eligible.id)
        #expect(client.writes.first?.loggedAt == eligible.loggedAt)
        #expect(try records(container).count == 1)
    }

    @Test(arguments: [AddDrinkSubmissionMethod.form, .recent])
    func atomicRollbackAndLocalSuccessStayIndependentOfHealth(method: AddDrinkSubmissionMethod) async throws {
        let container = try container()
        let client = TestExportClient()
        client.failures = [.water: .temporary, .caffeine: .authorization, .alcohol: .invalidPayload]
        try enable(container)
        let entry = entry()
        let store = WateredStore()
        let analytics = ExportAnalyticsRecorder()
        let handler = DrinkSubmissionHandler(store: store, analytics: analytics)
        #expect(throws: TestFailure.failed) {
            try handler.submit(entry, method: method) {
                try DrinkEntryPersistence.save($0, in: ModelContext(container), healthClient: client,
                    beforeSave: { throw TestFailure.failed })
            }
        }
        #expect(try records(container).isEmpty)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<PersistentDrinkEntry>()) == 0)
        #expect(store.entries.isEmpty)
        #expect(analytics.events.isEmpty)
        try handler.submit(entry, method: method) { try save($0, in: container, client: client) }
        let worker = worker(container, client: client)
        await worker.process()
        await worker.process(retryNow: true)
        #expect(store.entries.map(\.id) == [entry.id])
        #expect(analytics.events.count == 1)
        #expect(try records(container).count == 3)
        #expect(client.requestCount == 0)
        #expect(throws: DrinkEntryPersistence.SaveError.self) { try save(entry, in: container, client: client) }
        #expect(try records(container).count == 3)
    }

    @Test func partialResultsBackoffInvalidPayloadAndAcknowledgedSamplesNeverResend() async throws {
        let container = try container()
        let client = TestExportClient()
        client.failures = [.caffeine: .temporary, .alcohol: .invalidPayload]
        try enable(container)
        try save(entry(), in: container, client: client)
        let worker = worker(container, client: client)
        await worker.process()
        let first = try records(container)
        #expect(first.first { $0.typeID == "water" }?.status == "succeeded")
        #expect(first.first { $0.typeID == "caffeine" }?.nextAttemptAt == date.addingTimeInterval(30))
        #expect(first.first { $0.typeID == "alcohol" }?.status == "invalid")
        await worker.process()
        #expect(client.writes.count == 3)
        client.failures = [:]
        await worker.process(retryNow: true)
        #expect(client.writes.filter { $0.type == .water }.count == 1)
        #expect(client.writes.filter { $0.type == .caffeine }.count == 2)
        #expect(client.writes.filter { $0.type == .alcohol }.count == 1)
        // Removing a sample in Health is deliberately invisible. Acknowledged work stays sent.
        let reopened = workerForReopen(container, client: client)
        await reopened.process(retryNow: true)
        #expect(client.writes.count == 4)
    }

    private func workerForReopen(_ container: ModelContainer, client: TestExportClient) -> HealthExportCoordinator {
        worker(container, client: client)
    }

    @Test func permissionRevocationBlocksWithoutPromptsAndRestorationResumesOnlyOldEligibleWork() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(), in: container, client: client)
        client.statuses[.water] = .denied
        client.statuses[.caffeine] = .unavailable
        client.statuses[.alcohol] = .unknown
        let worker = worker(container, client: client)
        await worker.process()
        await worker.process(retryNow: true)
        #expect(client.writes.isEmpty)
        #expect(try records(container).allSatisfy { $0.status == "authorizationBlocked" && $0.nextAttemptAt == nil })
        try save(entry(), in: container, client: client)
        client.statuses[.water] = .authorized
        await worker.process()
        #expect(client.writes.map(\.type) == [.water])
        #expect(try records(container).count == 3)
        #expect(client.requestCount == 0)
    }

    @Test func invalidMappingAndCorruptPayloadStopIndependently() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(water: -1, caffeine: 0, abv: nil), in: container, client: client)
        #expect(try records(container).count == 1)
        #expect(try records(container).first?.status == "invalid")
        try save(entry(water: nil), in: container, client: client)
        let context = ModelContext(container)
        let caffeine = try #require(try context.fetch(FetchDescriptor<PersistentHealthExport>()).first { $0.typeID == "caffeine" })
        caffeine.payload = Data("broken".utf8)
        try context.save()
        await worker(container, client: client).process(retryNow: true)
        #expect(client.writes.map(\.type) == [.alcohol])
        #expect(try records(container).filter { $0.status == "invalid" }.count == 2)
    }

    @Test func beforeIOFailureDoesNotWriteAndAfterIOFailureRecoversFrozenPayload() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(caffeine: 0, abv: nil), in: container, client: client)
        let beforeIO = worker(container, client: client, beforeSave: { throw TestFailure.failed })
        await beforeIO.process()
        #expect(beforeIO.persistenceFailed)
        #expect(client.writes.isEmpty)
        #expect(try records(container).first?.mayHaveWritten == false)
        var commits = 0
        let beforeAck = worker(container, client: client, beforeSave: {
            commits += 1
            if commits == 2 { throw TestFailure.failed }
        })
        await beforeAck.process()
        #expect(beforeAck.persistenceFailed)
        #expect(try records(container).first?.status == "inFlight")
        #expect(try records(container).first?.mayHaveWritten == true)
        let original = try #require(client.writes.first)
        // Changing stored drink facts must not remap an uncertain write.
        let context = ModelContext(container)
        let drink = try #require(try context.fetch(FetchDescriptor<PersistentDrinkEntry>()).first)
        drink.waterAmount = 190
        drink.catalogueVersion = "changed"
        try context.save()
        await worker(container, client: client).process()
        #expect(client.writes == [original, original])
        #expect(client.writes.last?.syncVersion == 1)
        #expect(try records(container).first?.status == "succeeded")
    }

    @Test func concurrentRetriesAndDisableDuringFlightSerializeAndKeepOutcome() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(), in: container, client: client)
        client.suspendNext = true
        let worker = worker(container, client: client)
        let running = Task { await worker.process() }
        await client.waitUntilSuspended()
        await worker.process(retryNow: true)
        try worker.setEnabled(false)
        client.resume()
        await running.value
        #expect(client.writes.count == 1)
        #expect(client.maximumConcurrentWrites == 1)
        #expect(try records(container).filter { $0.status == "succeeded" }.count == 1)
        try worker.setEnabled(true)
        await worker.process()
        #expect(client.writes.count == 3)
        #expect(Set(client.writes.map(\.syncIdentifier)).count == 3)
    }

    @Test func deletionDuringFlightWinsAndRetainsCleanupAfterLateSuccess() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(), in: container, client: client)
        client.suspendNext = true
        let worker = worker(container, client: client)
        let running = Task { await worker.process() }
        await client.waitUntilSuspended()
        let context = ModelContext(container)
        let drinks = try context.fetch(FetchDescriptor<PersistentDrinkEntry>())
        _ = try DrinkEntryPersistence.delete(drinks, in: context, tracksHealthExports: true)
        #expect(try ModelContext(container).fetch(FetchDescriptor<PersistentDrinkEntry>()).first?.drinkEntry() == nil)
        client.resume()
        await running.value
        await worker.process(retryNow: true)
        let remaining = try records(container)
        #expect(client.writes.count == 1)
        #expect(remaining.count == 1)
        #expect(remaining.first?.operation == "delete")
        #expect(remaining.first?.status == "pending")
        #expect(remaining.first?.mayHaveWritten == true)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<PersistentDrinkEntry>()) == 1)
    }

    @Test func deletionRollbackAndNeverStartedDeletion() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(), in: container, client: client)
        let context = ModelContext(container)
        let drinks = try context.fetch(FetchDescriptor<PersistentDrinkEntry>())
        #expect(throws: TestFailure.failed) {
            try DrinkEntryPersistence.delete(drinks, in: context, tracksHealthExports: true, beforeSave: { throw TestFailure.failed })
        }
        #expect(try records(container).count == 3)
        #expect(try ModelContext(container).fetch(FetchDescriptor<PersistentDrinkEntry>()).first?.drinkEntry() != nil)
        _ = try DrinkEntryPersistence.delete(try context.fetch(FetchDescriptor<PersistentDrinkEntry>()), in: context, tracksHealthExports: true)
        await worker(container, client: client).process()
        #expect(client.writes.isEmpty)
        #expect(try records(container).isEmpty)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<PersistentDrinkEntry>()) == 0)
    }

    @Test func diskReopenPreservesPreferencePendingFrozenPayloadAndAcknowledgement() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let client = TestExportClient()
        client.failures[.water] = .temporary
        let original = entry(caffeine: 0, abv: nil)
        do {
            let container = try container(url: url)
            try enable(container)
            try save(original, in: container, client: client)
            await worker(container, client: client).process()
        }
        do {
            let reopened = try container(url: url)
            #expect(try HealthExportPersistence.isEnabled(in: ModelContext(reopened)))
            let row = try #require(try records(reopened).first)
            #expect(row.attemptCount == 1)
            #expect(row.nextAttemptAt == date.addingTimeInterval(30))
            #expect(row.mayHaveWritten)
            client.failures = [:]
            await worker(reopened, client: client).process(retryNow: true)
            #expect(client.writes[0] == client.writes[1])
        }
        do {
            let reopened = try container(url: url)
            #expect(try records(reopened).first?.status == "succeeded")
            await worker(reopened, client: client).process(retryNow: true)
            #expect(client.writes.count == 2)
        }
    }

    @Test func additiveEntityRolloutPreservesExistingStoreWithoutBackfill() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        let original = entry()
        do {
            let schema = Schema([PersistentDrinkEntry.self])
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            try DrinkEntryPersistence.save(original, in: ModelContext(old))
        }
        let upgraded = try container(url: url)
        let restored = try #require(try ModelContext(upgraded).fetch(FetchDescriptor<PersistentDrinkEntry>()).first?.drinkEntry())
        #expect(restored.catalogueSnapshot == original.catalogueSnapshot)
        #expect(restored.id == original.id)
        #expect(try records(upgraded).isEmpty)
        #expect(try !HealthExportPersistence.isEnabled(in: ModelContext(upgraded)))
    }

    @Test func dueRetriesUseOriginalPayloadAndIncreaseDelay() async throws {
        let container = try container()
        let client = TestExportClient()
        client.failures[.water] = .temporary
        try enable(container)
        try save(entry(caffeine: 0, abv: nil), in: container, client: client)
        var time = date
        let worker = HealthExportCoordinator(client: client, now: { time }, jitter: { 1 })
        worker.attach(to: container)
        await worker.process()
        time = date.addingTimeInterval(29)
        await worker.process()
        #expect(client.writes.count == 1)
        time = date.addingTimeInterval(30)
        await worker.process()
        #expect(client.writes.count == 2)
        #expect(client.writes[0] == client.writes[1])
        #expect(try records(container).first?.nextAttemptAt == time.addingTimeInterval(60))
    }

    @Test func platformBoundaryWritesOneSampleAndSanitizesFailures() async throws {
        let store = ExportSystemStore()
        let client = AppleHealthKitClient(store: store)
        let mapping = HealthSampleMapping.resolve(entry(), eligibleTypes: [.water])
        guard case .sample(let specification) = mapping[.water] else { Issue.record("Missing fixture"); return }
        try await client.save(specification)
        #expect(store.saved.count == 1)
        #expect(store.saved.first?.metadata?[HKMetadataKeySyncIdentifier] as? String == specification.syncIdentifier)
        #expect(store.saved.first?.metadata?[HKMetadataKeySyncVersion] as? Int == 1)
        #expect(store.requests == 0)
        for (code, expected) in [
            (HKError.Code.errorAuthorizationDenied, HealthExportFailure.authorization),
            (.errorAuthorizationNotDetermined, .authorization),
            (.errorHealthDataRestricted, .authorization),
            (.errorHealthDataUnavailable, .authorization),
            (.errorInvalidArgument, .invalidPayload),
            (.errorDatabaseInaccessible, .temporary)
        ] {
            store.failure = NSError(domain: HKErrorDomain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "sensitive payload must not escape"])
            do { try await client.save(specification); Issue.record("Expected sanitized error") }
            catch { #expect(error as? HealthExportFailure == expected) }
        }
        store.failure = nil
        store.status = .sharingDenied
        let count = store.saved.count
        do { try await client.save(specification); Issue.record("Expected denial") }
        catch { #expect(error as? HealthExportFailure == .authorization) }
        #expect(store.saved.count == count)
        #expect(store.requests == 0)
    }

    #if DEBUG
    @Test func debugFailureIsOneShotAndLeavesLocalSubmissionSuccessful() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        let store = WateredStore()
        let analytics = ExportAnalyticsRecorder()
        let entry = entry(caffeine: 0, abv: nil)
        try DrinkSubmissionHandler(store: store, analytics: analytics).submit(entry, method: .form) {
            try save($0, in: container, client: client)
        }
        let worker = worker(container, client: client)
        worker.debugHarness.nextIntervention = .failNextWrite
        await worker.process()
        #expect(client.writes.isEmpty)
        #expect(worker.debugHarness.nextIntervention == .none)
        #expect(try records(container).first?.status == "pending")
        #expect(try records(container).first?.failureCategory == "temporary")
        #expect(store.entries.map(\.id) == [entry.id])
        #expect(analytics.events.count == 1)
        await worker.process(retryNow: true)
        #expect(client.writes.count == 1)
        #expect(try records(container).first?.status == "succeeded")
        #expect(analytics.events.count == 1)
        #expect(client.requestCount == 0)
    }

    @Test func debugPauseKeepsDurableInFlightStateAndSerializesUntilResume() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(caffeine: 0, abv: nil), in: container, client: client)
        let worker = worker(container, client: client)
        worker.debugHarness.nextIntervention = .pauseAfterSave
        let running = Task { await worker.process() }
        defer { worker.debugHarness.resumeAcknowledgement() }
        for _ in 0..<1_000 where !worker.debugHarness.isPaused { await Task.yield() }
        #expect(worker.debugHarness.isPaused)
        #expect(worker.debugHarness.pausedType == .water)
        #expect(client.writes.count == 1)
        #expect(try records(container).first?.status == "inFlight")
        #expect(try records(container).first?.mayHaveWritten == true)
        await worker.process(retryNow: true)
        #expect(client.writes.count == 1)
        try worker.setEnabled(false)
        worker.debugHarness.resumeAcknowledgement()
        worker.debugHarness.resumeAcknowledgement() // Repeated taps are harmless.
        await running.value
        #expect(!worker.debugHarness.isPaused)
        #expect(try records(container).first?.status == "succeeded")
        try worker.setEnabled(true)
        await worker.process(retryNow: true)
        #expect(client.writes.count == 1)
    }

    @Test func debugPauseSurvivesFailureUntilSuccessAndRecoveryKeepsFrozenIdentity() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(caffeine: 0, abv: nil), in: container, client: client)
        client.failures[.water] = .temporary
        var commits = 0
        let worker = worker(container, client: client, beforeSave: {
            commits += 1
            if commits == 4 { throw TestFailure.failed }
        })
        worker.debugHarness.nextIntervention = .pauseAfterSave
        await worker.process()
        #expect(worker.debugHarness.nextIntervention == .pauseAfterSave)
        #expect(!worker.debugHarness.isPaused)
        client.failures = [:]
        let running = Task { await worker.process(retryNow: true) }
        defer { worker.debugHarness.resumeAcknowledgement() }
        for _ in 0..<1_000 where !worker.debugHarness.isPaused { await Task.yield() }
        #expect(worker.debugHarness.isPaused)
        worker.debugHarness.resumeAcknowledgement()
        await running.value
        #expect(worker.persistenceFailed)
        #expect(try records(container).first?.status == "inFlight")
        let recovered = workerForReopen(container, client: client)
        #expect(recovered.debugHarness.nextIntervention == .none)
        #expect(!recovered.debugHarness.isPaused)
        await recovered.process()
        #expect(client.writes.count == 3)
        #expect(Set(client.writes.map(\.syncIdentifier)).count == 1)
        #expect(client.writes.allSatisfy { $0 == client.writes.first })
        #expect(try records(container).first?.status == "succeeded")
    }

    @Test func deletionDuringDebugAcknowledgementPauseRetainsCleanupIntent() async throws {
        let container = try container()
        let client = TestExportClient()
        try enable(container)
        try save(entry(caffeine: 0, abv: nil), in: container, client: client)
        let worker = worker(container, client: client)
        worker.debugHarness.nextIntervention = .pauseAfterSave
        let running = Task { await worker.process() }
        defer { worker.debugHarness.resumeAcknowledgement() }
        for _ in 0..<1_000 where !worker.debugHarness.isPaused { await Task.yield() }
        #expect(worker.debugHarness.isPaused)
        let context = ModelContext(container)
        let drinks = try context.fetch(FetchDescriptor<PersistentDrinkEntry>())
        _ = try DrinkEntryPersistence.delete(drinks, in: context, tracksHealthExports: true)
        worker.debugHarness.resumeAcknowledgement()
        await running.value
        await worker.process(retryNow: true)
        #expect(client.writes.count == 1)
        #expect(try records(container).first?.operation == "delete")
        #expect(try records(container).first?.status == "pending")
    }
    #endif

    @Test func preferenceFailureRollsBackAndBackoffIsCappedWithJitter() throws {
        let container = try container()
        #expect(throws: TestFailure.failed) {
            try HealthExportPersistence.setEnabled(true, in: ModelContext(container), beforeSave: { throw TestFailure.failed })
        }
        #expect(try !HealthExportPersistence.isEnabled(in: ModelContext(container)))
        #expect(HealthExportCoordinator.retryDelay(attempt: 1, jitter: 0) == 15)
        #expect(HealthExportCoordinator.retryDelay(attempt: 2, jitter: 1) == 60)
        #expect(HealthExportCoordinator.retryDelay(attempt: Int.max, jitter: 1) == 21_600)
        #expect(HealthExportCoordinator.retryDelay(attempt: 10, jitter: .nan).isFinite)
    }
}

@MainActor
private final class TestExportClient: HealthExportClient {
    var statuses: [HealthWriteType: HealthWriteAuthorization] = Dictionary(uniqueKeysWithValues: HealthWriteType.allCases.map { ($0, .authorized) })
    var failures: [HealthWriteType: HealthExportFailure] = [:]
    var writes: [HealthSampleSpecification] = []
    var requestCount = 0
    var suspendNext = false
    var maximumConcurrentWrites = 0
    private var concurrent = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var suspendedObserver: CheckedContinuation<Void, Never>?
    func authorization(for type: HealthWriteType) -> HealthWriteAuthorization { statuses[type] ?? .unavailable }
    func requestWriteAuthorization() async throws { requestCount += 1 }
    func save(_ specification: HealthSampleSpecification) async throws {
        concurrent += 1
        maximumConcurrentWrites = max(maximumConcurrentWrites, concurrent)
        defer { concurrent -= 1 }
        writes.append(specification)
        if suspendNext {
            suspendNext = false
            await withCheckedContinuation { continuation = $0; suspendedObserver?.resume(); suspendedObserver = nil }
        }
        if let failure = failures[specification.type] { throw failure }
    }
    func waitUntilSuspended() async {
        if continuation != nil { return }
        await withCheckedContinuation { suspendedObserver = $0 }
    }
    func resume() { continuation?.resume(); continuation = nil }
}

@MainActor
private final class ExportAnalyticsRecorder: AnalyticsClient {
    var events: [AnalyticsEvent] = []
    func track(_ event: AnalyticsEvent) { events.append(event) }
}

private enum TestFailure: Error { case failed }

@MainActor
private final class ExportSystemStore: HealthAuthorizationStore, HealthSampleStore {
    var isAvailable = true
    var status: HKAuthorizationStatus = .sharingAuthorized
    var failure: Error?
    var saved: [HKQuantitySample] = []
    var requests = 0
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus { status }
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws { requests += 1 }
    func save(_ sample: HKQuantitySample) async throws {
        if let failure { throw failure }
        saved.append(sample)
    }
}
