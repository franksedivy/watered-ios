#if DEBUG
import Foundation
import SwiftData

/// Synthetic permission and work fixtures for explicitly isolated UI-test launches.
/// Never constructs a Health store. Real preference writes, worker retries and cleanup
/// still run through their production boundaries; only platform responses are faked.
@MainActor
final class DebugHealthUITestClient: HealthExportClient {
    private let scenario: String
    private var statuses: [HealthWriteType: HealthWriteAuthorization]
    private var shouldFailPreferenceSave: Bool
    private var hasSeeded = false

    /// Starts the named scenario without requesting permissions or creating work yet.
    init(scenario: String) {
        self.scenario = scenario
        shouldFailPreferenceSave = scenario == "saveFailure"
        let initial: HealthWriteAuthorization = switch scenario {
        case "denied": .denied
        case "restricted", "cleanup": .notDetermined
        case "retry", "paused", "saveFailure": .authorized
        default: .unavailable
        }
        statuses = Dictionary(uniqueKeysWithValues: HealthWriteType.allCases.map { ($0, initial) })
        if scenario == "mixed" {
            statuses = [.water: .authorized, .caffeine: .denied, .alcohol: .notDetermined]
        }
    }

    func authorization(for type: HealthWriteType) -> HealthWriteAuthorization {
        statuses[type] ?? .unavailable
    }

    /// Cleanup tests simulate restoring grants through an explicit permission action.
    /// Mixed grants deliberately remain mixed after completion to catch false connection claims.
    func requestWriteAuthorization() async throws {
        if scenario == "restricted" { throw HealthAuthorizationError.restricted }
        if scenario == "cleanup" {
            statuses = Dictionary(uniqueKeysWithValues: HealthWriteType.allCases.map { ($0, .authorized) })
        }
    }

    /// Acknowledges permitted fake writes without constructing or contacting a Health store.
    func save(_ specification: HealthSampleSpecification) async throws {
        guard authorization(for: specification.type) == .authorized else { throw HealthExportFailure.authorization }
    }

    /// Acknowledges permitted fake cleanup; retained details are purged by the real worker.
    func delete(_ target: HealthDeletionTarget) async throws {
        guard authorization(for: target.type) == .authorized else { throw HealthExportFailure.authorization }
    }

    /// One failed settings transaction; the next explicit attempt can succeed.
    func beforeSave() throws {
        if shouldFailPreferenceSave {
            shouldFailPreferenceSave = false
            throw HealthExportFailure.temporary
        }
    }

    /// Called once before the worker starts, only on the UI test's in-memory container.
    /// Future retry dates keep seeded temporary failures stable until Retry now is tapped.
    func seed(in context: ModelContext) throws {
        guard !hasSeeded else { return }
        hasSeeded = true
        guard ["retry", "paused", "cleanup"].contains(scenario) else { return }
        try HealthExportPersistence.setEnabled(scenario == "retry", in: context, at: Date())
        let entry = DrinkEntry(amount: .init(value: 200, unit: .milliliters), date: Date(),
            catalogueSnapshot: .init(drinkID: "ui-fixture", drinkName: "UI fixture", caffeineVariant: .regular,
                shotCount: nil, hydrationContribution: 200, caffeineAmount: 40,
                catalogueVersion: "fixture", calculationVersion: "fixture", catalogueSchemaVersion: 6,
                waterAmount: 200, alcoholABV: 0.1))
        let stored = PersistentDrinkEntry(drinkEntry: entry)
        context.insert(stored)
        for type in HealthWriteType.allCases {
            guard case .sample(let sample) = HealthSampleMapping.resolve(entry, eligibleTypes: Set(HealthWriteType.allCases))[type] else { continue }
            let record = PersistentHealthExport(entryID: entry.id, type: type, payload: try JSONEncoder().encode(sample))
            if scenario == "cleanup" {
                guard type == .water else { continue }
                stored.deletedAt = Date()
                record.operation = "delete"
                record.status = "authorizationBlocked"
                record.mayHaveWritten = true
            } else {
                switch type {
                case .water:
                    record.nextAttemptAt = .distantFuture
                    if scenario == "retry" { record.failureCategory = "temporary" }
                case .caffeine:
                    record.status = "succeeded"
                    record.mayHaveWritten = true
                case .alcohol:
                    record.status = "invalid"
                    record.failureCategory = "invalidPayload"
                }
            }
            context.insert(record)
        }
        try context.save()
    }
}
#endif
