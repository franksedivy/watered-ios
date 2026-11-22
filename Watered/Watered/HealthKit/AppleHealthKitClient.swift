import HealthKit

/// Narrow system seam allows authorization tests without opening a personal Health store.
@MainActor
protocol HealthAuthorizationStore: AnyObject {
    var isAvailable: Bool { get }
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws
}

@MainActor
private final class AppleHealthAuthorizationStore: HealthAuthorizationStore, HealthSampleStore {
    private let store = HKHealthStore()
    func save(_ sample: HKQuantitySample) async throws { try await store.save(sample) }
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

    func save(_ specification: HealthSampleSpecification) async throws {
        guard authorization(for: specification.type) == .authorized else { throw HealthExportFailure.authorization }
        let sample: HKQuantitySample
        do { sample = try HealthSampleFactory.makeSample(from: specification) }
        catch { throw HealthExportFailure.invalidPayload }
        guard let writer = store as? any HealthSampleStore else { throw HealthExportFailure.temporary }
        do { try await writer.save(sample) }
        catch {
            let failure = error as NSError
            if failure.domain == HKErrorDomain {
                switch failure.code {
                case HKError.Code.errorAuthorizationDenied.rawValue,
                     HKError.Code.errorAuthorizationNotDetermined.rawValue,
                     HKError.Code.errorHealthDataRestricted.rawValue,
                     HKError.Code.errorHealthDataUnavailable.rawValue:
                    throw HealthExportFailure.authorization
                case HKError.Code.errorInvalidArgument.rawValue:
                    throw HealthExportFailure.invalidPayload
                default: break
                }
            }
            throw HealthExportFailure.temporary
        }
    }

    private static func quantityType(for type: HealthWriteType) -> HKQuantityType {
        switch type {
        case .water: return HKQuantityType(.dietaryWater)
        case .caffeine: return HKQuantityType(.dietaryCaffeine)
        case .alcohol: return HKQuantityType(.numberOfAlcoholicBeverages)
        }
    }
}
