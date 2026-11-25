import Foundation

/// The reviewed write scope. App opt-in is a separate, persisted lifecycle decision.
nonisolated enum HealthWriteType: String, Codable, CaseIterable, Hashable, Sendable {
    // Persisted identity components; preserve these values when renaming Swift cases.
    case water = "water"
    case caffeine = "caffeine"
    case alcohol = "alcohol"
}

nonisolated enum HealthWriteAuthorization: Equatable, Sendable {
    case notDetermined, authorized, denied, unavailable
    /// A future platform status must never be treated as permission.
    case unknown
}

/// Non-sensitive operation failures; never retain HealthKit payloads or error descriptions.
nonisolated enum HealthAuthorizationError: Error, Equatable {
    case unavailable, restricted, requestFailed, requestInProgress
}

/// Exposes per-type write permission independently of the app's persisted export preference.
@MainActor
protocol HealthKitClient: AnyObject {
    /// Returns the current write-permission state without prompting or changing app opt-in.
    /// An authorized result does not establish export eligibility or successful sample delivery.
    func authorization(for type: HealthWriteType) -> HealthWriteAuthorization
    /// Requests permission to write water, caffeine and alcoholic-beverage quantities, with no read access.
    /// Call only in response to an explicit permission action, never launch, save or retry.
    /// Successful completion does not imply any grant; callers must refresh each type with
    /// `authorization(for:)`. This request does not change the persisted app opt-in preference.
    /// - Throws: A `HealthAuthorizationError` for an unavailable or restricted service,
    ///   a failed request or an overlapping request; denial is represented by per-type status.
    func requestWriteAuthorization() async throws
}

/// Controllable, HealthKit-free dependency for previews and isolated tests.
@MainActor
final class FakeHealthKitClient: HealthKitClient {
    var statuses: [HealthWriteType: HealthWriteAuthorization]
    var requestError: HealthAuthorizationError?
    private(set) var requestCount = 0

    init(statuses: [HealthWriteType: HealthWriteAuthorization] = [:]) {
        self.statuses = statuses
    }

    func authorization(for type: HealthWriteType) -> HealthWriteAuthorization {
        statuses[type] ?? .unavailable
    }

    func requestWriteAuthorization() async throws {
        requestCount += 1
        if let requestError { throw requestError }
    }
}

nonisolated enum HealthExportFailure: Error, Equatable {
    case temporary, authorization, invalidPayload
}

@MainActor
protocol HealthExportClient: HealthKitClient {
    /// Writes one frozen type. Never requests permission; raw platform errors stay private.
    func save(_ specification: HealthSampleSpecification) async throws
    /// Deletes only this app's samples matching one entry/type identity. Zero matches succeeds.
    func delete(_ target: HealthDeletionTarget) async throws
}

extension FakeHealthKitClient: HealthExportClient {
    func delete(_ target: HealthDeletionTarget) async throws {
        throw HealthExportFailure.authorization
    }

    func save(_ specification: HealthSampleSpecification) async throws {
        throw HealthExportFailure.authorization
    }
}
