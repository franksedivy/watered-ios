import Foundation
import Observation
import SwiftData

/// One app-lifetime executor. MainActor serialization includes preference/creation commits;
/// a separate context keeps asynchronous acknowledgements away from unrelated UI edits.
@MainActor @Observable
final class HealthExportCoordinator {
    #if DEBUG
    let debugHarness = DebugHealthExportHarness()
    #endif

    let client: any HealthExportClient
    /// Reports a processing or scheduling persistence failure, not a per-type Health failure.
    /// Reset when an attached, non-coalesced processing call starts.
    private(set) var persistenceFailed = false
    private(set) var isProcessing = false
    /// Advances after each completed pass, even if a fast pass coalesces busy-state updates.
    /// Presentation uses this to reload durable outcomes from a fresh context.
    private(set) var progressRevision = 0
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var rerunRequested = false
    @ObservationIgnored private var retryRequested = false
    @ObservationIgnored private var active = false
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let jitter: () -> Double
    @ObservationIgnored private let beforeSave: () throws -> Void

    init(client: any HealthExportClient, now: @escaping () -> Date = Date.init,
         jitter: @escaping () -> Double = { Double.random(in: 0...1) },
         beforeSave: @escaping () throws -> Void = {}) {
        self.client = client
        self.now = now
        self.jitter = jitter
        self.beforeSave = beforeSave
    }

    func attach(to container: ModelContainer) {
        guard context == nil else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        #if DEBUG
        if let fixture = client as? DebugHealthUITestClient {
            do { try fixture.seed(in: context) }
            catch { preconditionFailure("Could not prepare isolated Health UI fixture") }
        }
        #endif
        self.context = context
    }

    /// Controls foreground wake-ups and scheduled retries; activation requests a processing pass.
    /// Deactivation cancels the timer, not an ongoing Health operation or its acknowledgement.
    /// A pass started while active stops starting further record attempts after deactivation.
    /// Direct `process()` calls can still run while inactive for deterministic tests.
    func setActive(_ active: Bool) {
        self.active = active
        if active { wake() } else { timer?.cancel(); timer = nil }
    }

    /// Commits the preference before reporting a user-initiated off-to-on transition.
    /// Profile supplies its analytics client; harness/operational callers default to no-op.
    /// Permission grants and export outcomes never enter this property-free interaction event.
    func setEnabled(_ enabled: Bool, analytics: (any AnalyticsClient)? = nil) throws {
        guard let context else { throw PersistenceError.notAttached }
        let preferenceContext = ModelContext(context.container)
        let wasEnabled = try HealthExportPersistence.isEnabled(in: preferenceContext)
        try HealthExportPersistence.setEnabled(enabled, in: preferenceContext, at: now(), beforeSave: beforeSave)
        if enabled && !wasEnabled { analytics?.track(.appleHealthSyncEnabled) }
        wake()
    }

    /// Requests a retry without prompting for permissions or resubmitting the local drink.
    /// Bypasses pending backoff only; authorization, upload preference and terminal states
    /// still apply. Cleanup remains eligible with sync disabled. Inactive requests wait for a pass.
    func retryNow() { wake(retryNow: true) }

    /// Coalesces a processing request and cancels any scheduled retry timer.
    /// Starts processing only while active; otherwise retains the request for a later pass.
    /// - Parameter retryNow: Whether the next pass should bypass pending retry deadlines.
    func wake(retryNow: Bool = false) {
        retryRequested = retryRequested || retryNow
        rerunRequested = true
        timer?.cancel()
        timer = nil
        guard active else { return }
        Task { await process() }
    }

    /// Processes durable upload and cleanup work, including uncertain in-flight attempts.
    /// Requires attachment but can be called directly while inactive for deterministic tests.
    /// Concurrent calls request another pass and return without awaiting the running worker;
    /// no second worker starts I/O. Unattached calls retain a request and return.
    ///
    /// Uploads require sync enabled; cleanup does not. Both retain authorization checks,
    /// and succeeded or invalid records are not retried. Persistence failures are reported
    /// through `persistenceFailed`, not thrown; Health failures become per-record outcomes.
    /// Finishing processing advances `progressRevision` and schedules retries only while active.
    ///
    /// - Parameter retryNow: Bypasses pending retry deadlines without overriding other checks.
    func process(retryNow: Bool = false) async {
        retryRequested = retryRequested || retryNow
        guard !isProcessing, let context else { rerunRequested = true; return }
        let startedActive = active
        isProcessing = true
        persistenceFailed = false
        defer {
            isProcessing = false
            progressRevision += 1
            scheduleNextAttempt()
        }
        do {
            repeat {
                rerunRequested = false
                let force = retryRequested
                retryRequested = false
                let scan = ModelContext(context.container)
                let identities = try scan.fetch(FetchDescriptor<PersistentHealthExport>(sortBy: [SortDescriptor(\.identity)])).map(\.identity)
                for identity in identities {
                    if startedActive && !active { break }
                    let attempt = ModelContext(context.container)
                    attempt.autosaveEnabled = false
                    let enabled = try HealthExportPersistence.isEnabled(in: attempt)
                    guard let record = try attempt.fetch(FetchDescriptor<PersistentHealthExport>(predicate: #Predicate { $0.identity == identity })).first else { continue }
                    guard ["upload", "delete"].contains(record.operation), ["pending", "inFlight", "authorizationBlocked"].contains(record.status) else { continue }
                    if record.operation == "upload" && !enabled { continue }
                    if !force, record.status == "pending", let due = record.nextAttemptAt, due > now() { continue }
                    if record.operation == "delete" { try await cleanup(record, in: attempt) }
                    else { try await upload(record, in: attempt) }
                }
                let purge = ModelContext(context.container)
                try HealthExportPersistence.purgeCompletedDeletions(in: purge)
                if purge.hasChanges { try commit(purge) }
            } while rerunRequested
        } catch {
            context.rollback()
            persistenceFailed = true
        }
    }

    private func upload(_ record: PersistentHealthExport, in context: ModelContext) async throws {
        let entryID = record.entryID
        let entry = try context.fetch(FetchDescriptor<PersistentDrinkEntry>(predicate: #Predicate { $0.id == entryID })).first
        guard let entry, entry.deletedAt == nil else {
            // Conservative recovery if an older caller removed the drink without a tombstone.
            if record.mayHaveWritten {
                record.operation = "delete"
                record.attemptCount = 0
                rerunRequested = true
                record.status = "pending"
                record.nextAttemptAt = nil
            } else { context.delete(record) }
            try commit(context)
            return
        }
        guard let type = HealthWriteType(rawValue: record.typeID), let data = record.payload,
              let specification = try? JSONDecoder().decode(HealthSampleSpecification.self, from: data),
              specification.entryID == record.entryID, specification.type == type,
              specification.syncIdentifier == record.identity,
              specification.policyVersion == record.policyVersion,
              specification.syncVersion == record.syncVersion,
              (try? HealthSampleFactory.makeSample(from: specification)) != nil else {
            record.status = "invalid"
            record.failureCategory = "invalidPayload"
            record.nextAttemptAt = nil
            try commit(context)
            return
        }
        guard client.authorization(for: type) == .authorized else {
            record.status = "authorizationBlocked"
            record.failureCategory = "authorization"
            record.nextAttemptAt = nil
            try commit(context)
            return
        }
        record.status = "inFlight"
        record.mayHaveWritten = true
        record.attemptCount = min(record.attemptCount, 1_000_000) + 1
        record.nextAttemptAt = nil
        try commit(context)

        let failure: HealthExportFailure?
        do {
            #if DEBUG
            try debugHarness.beforeWrite()
            #endif
            try await client.save(specification)
            #if DEBUG
            await debugHarness.afterSuccessfulWrite(type: specification.type)
            #endif
            failure = nil
        } catch { failure = error as? HealthExportFailure ?? .temporary }

        // Re-fetch through a fresh context after suspension: deletion/preference commits may
        // have happened in the UI context. Never overwrite deletion with a late upload result.
        let acknowledgement = ModelContext(context.container)
        acknowledgement.autosaveEnabled = false
        let identity = record.identity
        guard let current = try acknowledgement.fetch(FetchDescriptor<PersistentHealthExport>(predicate: #Predicate { $0.identity == identity })).first else {
            throw PersistenceError.missingIntent
        }
        let currentEntry = try acknowledgement.fetch(FetchDescriptor<PersistentDrinkEntry>(predicate: #Predicate { $0.id == entryID })).first
        if current.operation == "delete" || currentEntry?.deletedAt != nil || currentEntry == nil {
            current.operation = "delete"
            current.attemptCount = 0
            rerunRequested = true
            current.status = "pending"
            current.nextAttemptAt = nil
            current.failureCategory = nil
        } else {
            apply(failure, to: current)
        }
        try commit(acknowledgement)
    }

    private func cleanup(_ record: PersistentHealthExport, in context: ModelContext) async throws {
        let entryID = record.entryID
        let entry = try context.fetch(FetchDescriptor<PersistentDrinkEntry>(predicate: #Predicate { $0.id == entryID })).first
        guard entry == nil || entry?.deletedAt != nil,
              let type = HealthWriteType(rawValue: record.typeID),
              record.identity == HealthSampleSpecification.syncIdentifier(entryID: entryID, type: type) else {
            apply(.invalidPayload, to: record)
            try commit(context)
            return
        }
        guard client.authorization(for: type) == .authorized else {
            apply(.authorization, to: record)
            try commit(context)
            return
        }
        let target = HealthDeletionTarget(entryID: entryID, type: type, syncIdentifier: record.identity)
        record.status = "inFlight"
        record.attemptCount = min(record.attemptCount, 1_000_000) + 1
        record.nextAttemptAt = nil
        try commit(context)
        let failure: HealthExportFailure?
        do {
            #if DEBUG
            try debugHarness.beforeDeletion()
            #endif
            try await client.delete(target)
            #if DEBUG
            await debugHarness.afterSuccessfulDeletion(type: type)
            #endif
            failure = nil
        } catch { failure = error as? HealthExportFailure ?? .temporary }
        let acknowledgement = ModelContext(context.container)
        acknowledgement.autosaveEnabled = false
        let identity = target.syncIdentifier
        guard let current = try acknowledgement.fetch(FetchDescriptor<PersistentHealthExport>(predicate: #Predicate { $0.identity == identity })).first,
              current.operation == "delete" else { throw PersistenceError.missingIntent }
        apply(failure, to: current)
        if failure == nil {
            try HealthExportPersistence.purgeCompletedDeletions(in: acknowledgement)
            // Orphaned intents from an older caller have no drink left to purge.
            if entry == nil { acknowledgement.delete(current) }
        }
        try commit(acknowledgement)
    }

    private func apply(_ failure: HealthExportFailure?, to current: PersistentHealthExport) {
        switch failure {
        case nil:
            current.status = "succeeded"
            current.failureCategory = nil
            current.nextAttemptAt = nil
        case .authorization:
            current.status = "authorizationBlocked"
            current.failureCategory = "authorization"
            current.nextAttemptAt = nil
        case .invalidPayload:
            current.status = "invalid"
            current.failureCategory = "invalidPayload"
            current.nextAttemptAt = nil
        case .temporary:
            current.status = "pending"
            current.failureCategory = "temporary"
            current.nextAttemptAt = now().addingTimeInterval(Self.retryDelay(attempt: current.attemptCount, jitter: jitter()))
        }
    }

    private func commit(_ context: ModelContext) throws {
        do { try beforeSave(); try context.save() }
        catch { context.rollback(); throw error }
    }

    /// Equal jitter: first delay 15–30 seconds, doubling to a hard 6-hour cap.
    static func retryDelay(attempt: Int, jitter: Double) -> TimeInterval {
        let ceiling = min(21_600.0, 30 * pow(2, Double(min(20, max(0, attempt - 1)))))
        let fraction = jitter.isFinite ? min(1, max(0, jitter)) : 0.5
        return ceiling * (0.5 + fraction * 0.5)
    }

    private func scheduleNextAttempt() {
        guard active, let context else { return }
        do {
            let context = ModelContext(context.container)
            let enabled = try HealthExportPersistence.isEnabled(in: context)
            let records = try context.fetch(FetchDescriptor<PersistentHealthExport>())
            let due = records.filter { ($0.operation == "delete" || (enabled && $0.operation == "upload")) && $0.status == "pending" }
                .compactMap(\.nextAttemptAt).min()
            guard persistenceFailed || due != nil else { return }
            let delay = persistenceFailed ? 30 : max(1, due!.timeIntervalSince(now()))
            timer = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, self.active else { return }
                await self.process()
            }
        } catch { persistenceFailed = true }
    }

    enum PersistenceError: Error { case notAttached, missingIntent }
}
