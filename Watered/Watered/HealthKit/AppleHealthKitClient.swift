import HealthKit

/// Narrow system seam allows authorization tests without opening a personal Health store.
@MainActor
protocol HealthAuthorizationStore: AnyObject {
    var isAvailable: Bool { get }
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws
}

@MainActor
private final class AppleHealthAuthorizationStore: HealthAuthorizationStore {
    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws {
        try await store.requestAuthorization(toShare: toShare, read: read)
    }
}

/// Owns one system store for the app lifetime. Does not save samples or change sync opt-in.
@MainActor
final class AppleHealthKitClient: HealthKitClient {
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

    private static func quantityType(for type: HealthWriteType) -> HKQuantityType {
        switch type {
        case .water: return HKQuantityType(.dietaryWater)
        case .caffeine: return HKQuantityType(.dietaryCaffeine)
        case .alcohol: return HKQuantityType(.numberOfAlcoholicBeverages)
        }
    }
}
