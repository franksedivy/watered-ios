import HealthKit

/// Narrow system seam allows authorization tests without opening a personal Health store.
@MainActor
protocol HealthAuthorizationStore: AnyObject {
    var isAvailable: Bool { get }
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws
}

@MainActor
private final class AppleHealthAuthorizationStore: HealthAuthorizationStore, HealthSampleStore, HealthDeletionStore {
    private let store = HKHealthStore()
    var appSourcePredicate: NSPredicate { HKQuery.predicateForObjects(from: HKSource.default()) }
    func save(_ sample: HKQuantitySample) async throws { try await store.save(sample) }
    func deleteObjects(of type: HKObjectType, predicate: NSPredicate) async throws -> Int {
        try await store.deleteObjects(of: type, predicate: predicate)
    }
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws {
        try await store.requestAuthorization(toShare: toShare, read: read)
    }
}

@MainActor
protocol HealthSampleStore: AnyObject {
    func save(_ sample: HKQuantitySample) async throws
}

@MainActor
protocol HealthDeletionStore: AnyObject {
    /// The production store resolves the app source; isolated tests never open that boundary.
    var appSourcePredicate: NSPredicate { get }
    func deleteObjects(of type: HKObjectType, predicate: NSPredicate) async throws -> Int
}

/// Owns one system store for the app lifetime. App opt-in remains a persistence concern.
@MainActor
final class AppleHealthKitClient: HealthExportClient {
    private let store: any HealthAuthorizationStore
    private var isRequesting = false

    init() { store = AppleHealthAuthorizationStore() }
    init(store: any HealthAuthorizationStore) { self.store = store }

    func authorization(for type: HealthWriteType) -> HealthWriteAuthorization {
        guard store.isAvailable else { return .unavailable }
        switch store.authorizationStatus(for: Self.quantityType(for: type)) {
        case .notDetermined: return .notDetermined
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        @unknown default: return .unknown
        }
    }

    func requestWriteAuthorization() async throws {
        guard store.isAvailable else { throw HealthAuthorizationError.unavailable }
        guard !isRequesting else { throw HealthAuthorizationError.requestInProgress }
        isRequesting = true
        defer { isRequesting = false }
        do {
            try await store.requestAuthorization(
                toShare: Set(HealthWriteType.allCases.map { Self.quantityType(for: $0) }),
                read: []
            )
        } catch {
            let failure = error as NSError
            if failure.domain == HKErrorDomain {
                switch failure.code {
                case HKError.Code.errorHealthDataUnavailable.rawValue:
                    throw HealthAuthorizationError.unavailable
                case HKError.Code.errorHealthDataRestricted.rawValue:
                    throw HealthAuthorizationError.restricted
                default: break
                }
            }
            throw HealthAuthorizationError.requestFailed
        }
    }

    /// Writes one frozen specification after checking current write permission and factory validation.
    /// Never prompts or checks app opt-in; the coordinator owns eligibility and durable acknowledgement.
    /// - Parameter specification: Captured sample values to construct without recalculation.
    /// - Throws: `HealthExportFailure.authorization` for missing permission or platform access failures,
    ///   `.invalidPayload` for factory rejection or a platform invalid-argument error, and `.temporary`
    ///   for an unavailable writer or other platform errors. Raw platform errors do not escape.
    func save(_ specification: HealthSampleSpecification) async throws {
        guard authorization(for: specification.type) == .authorized else { throw HealthExportFailure.authorization }
        let sample: HKQuantitySample
        do { sample = try HealthSampleFactory.makeSample(from: specification) }
        catch { throw HealthExportFailure.invalidPayload }
        guard let writer = store as? any HealthSampleStore else { throw HealthExportFailure.temporary }
        do { try await writer.save(sample) }
        catch { throw Self.exportFailure(for: error) }
    }

    /// Deletes samples of the requested type matching both this app's source and entry/type sync identity.
    /// Validates identity before checking current write permission; never prompts or checks app opt-in.
    /// A successful zero-match deletion is success. The coordinator must persist acknowledgement
    /// before treating cleanup as complete and purging retained local records.
    /// - Parameter target: Stable cleanup identity; no upload payload or sample UUID is required.
    /// - Throws: `HealthExportFailure.invalidPayload` for invalid identity or a platform invalid-argument
    ///   error, `.authorization` for missing permission or platform access failures, and `.temporary`
    ///   for an unavailable deletion store or other platform errors. Raw platform errors do not escape.
    func delete(_ target: HealthDeletionTarget) async throws {
        guard target.isValid else { throw HealthExportFailure.invalidPayload }
        guard authorization(for: target.type) == .authorized else { throw HealthExportFailure.authorization }
        guard let deletionStore = store as? any HealthDeletionStore else { throw HealthExportFailure.temporary }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            deletionStore.appSourcePredicate,
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                                       allowedValues: [target.syncIdentifier])
        ])
        do {
            // HealthKit also enforces ownership. A successful zero-match request resolves cleanup.
            _ = try await deletionStore.deleteObjects(of: Self.quantityType(for: target.type), predicate: predicate)
        } catch { throw Self.exportFailure(for: error) }
    }

    private static func exportFailure(for error: Error) -> HealthExportFailure {
        let failure = error as NSError
        if failure.domain == HKErrorDomain {
            switch failure.code {
            case HKError.Code.errorAuthorizationDenied.rawValue,
                 HKError.Code.errorAuthorizationNotDetermined.rawValue,
                 HKError.Code.errorHealthDataRestricted.rawValue,
                 HKError.Code.errorHealthDataUnavailable.rawValue:
                return .authorization
            case HKError.Code.errorInvalidArgument.rawValue:
                return .invalidPayload
            default: break
            }
        }
        return .temporary
    }

    private static func quantityType(for type: HealthWriteType) -> HKQuantityType {
        switch type {
        case .water: return HKQuantityType(.dietaryWater)
        case .caffeine: return HKQuantityType(.dietaryCaffeine)
        case .alcohol: return HKQuantityType(.numberOfAlcoholicBeverages)
        }
    }
}
