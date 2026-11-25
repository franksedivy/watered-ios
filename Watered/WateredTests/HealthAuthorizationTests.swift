import Foundation
import HealthKit
import Testing
@testable import Watered

@MainActor
struct HealthAuthorizationTests {
    // GIVEN a user-requested authorization with mixed per-type results from a store spy,
    // THEN only the three reviewed write types are requested and completion preserves the actual grants.
    @Test func requestUsesOnlyReviewedWriteTypesAndDoesNotInferGrants() async throws {
        let store = AuthorizationStoreSpy()
        store.statuses = [
            HKQuantityTypeIdentifier.dietaryWater.rawValue: .sharingAuthorized,
            HKQuantityTypeIdentifier.dietaryCaffeine.rawValue: .sharingDenied
        ]
        let controller = HealthAuthorizationController(client: AppleHealthKitClient(store: store))
        await controller.requestAuthorizationFromUserAction()
        #expect(store.shared == Set([
            HKQuantityType(.dietaryWater), HKQuantityType(.dietaryCaffeine),
            HKQuantityType(.numberOfAlcoholicBeverages)
        ]))
        #expect(store.read.isEmpty)
        #expect(controller.statuses[.water] == .authorized)
        #expect(controller.statuses[.caffeine] == .denied)
        #expect(controller.statuses[.alcohol] == .notDetermined)
        #expect(controller.requestError == nil)
    }

    // GIVEN Health unavailable during refresh and a user authorization action,
    // THEN the controller reports unavailability without querying grants or requesting access.
    @Test func unavailableNeverAccessesStoreOrPrompts() async {
        let store = AuthorizationStoreSpy()
        store.isAvailable = false
        let controller = HealthAuthorizationController(client: AppleHealthKitClient(store: store))
        controller.refreshAuthorization()
        await controller.requestAuthorizationFromUserAction()
        #expect(store.requestCount == 0)
        #expect(store.statusCount == 0)
        #expect(controller.requestError == .unavailable)
        #expect(HealthWriteType.allCases.allSatisfy { controller.statuses[$0] == .unavailable })
    }

    // GIVEN write permissions changed after an initial refresh,
    // THEN operation checks and subsequent refresh observe current grants without prompting.
    @Test func refreshAndOperationCheckObserveRevocationWithoutPrompting() {
        let client = FakeHealthKitClient(statuses: [.water: .authorized, .alcohol: .denied])
        let controller = HealthAuthorizationController(client: client)
        controller.refreshAuthorization()
        client.statuses[.water] = .denied
        #expect(controller.currentAuthorization(for: .water) == .denied)
        client.statuses[.alcohol] = .authorized
        controller.refreshAuthorization()
        #expect(controller.statuses[.alcohol] == .authorized)
        #expect(client.requestCount == 0)
    }

    // GIVEN restricted, unavailable and unexpected authorization-request errors,
    // THEN sanitized errors preserve per-type grants and a later successful request clears the error.
    @Test func operationErrorsAreSanitizedAndDoNotOverwritePerTypeGrants() async {
        let store = AuthorizationStoreSpy()
        let controller = HealthAuthorizationController(client: AppleHealthKitClient(store: store))
        let cases: [(Error, HealthAuthorizationError)] = [
            (NSError(domain: HKErrorDomain, code: HKError.Code.errorHealthDataRestricted.rawValue), .restricted),
            (NSError(domain: HKErrorDomain, code: HKError.Code.errorHealthDataUnavailable.rawValue), .unavailable),
            (NSError(domain: "synthetic", code: 1, userInfo: [NSLocalizedDescriptionKey: "private detail"]), .requestFailed)
        ]
        store.statuses[HKQuantityTypeIdentifier.dietaryWater.rawValue] = .sharingAuthorized
        for (error, expected) in cases {
            store.error = error
            await controller.requestAuthorizationFromUserAction()
            #expect(controller.requestError == expected)
            #expect(controller.statuses[.water] == .authorized)
            #expect(!controller.isRequesting)
        }
        store.error = nil
        await controller.requestAuthorizationFromUserAction()
        #expect(controller.requestError == nil)
    }

    // GIVEN an authorization request suspended in the store spy,
    // THEN another user action does not start a second request and completion clears the busy state.
    @Test func concurrentUserActionsDoNotStartOverlappingRequests() async {
        let store = AuthorizationStoreSpy()
        store.shouldSuspend = true
        let controller = HealthAuthorizationController(client: AppleHealthKitClient(store: store))
        let first = Task { await controller.requestAuthorizationFromUserAction() }
        while store.continuation == nil { await Task.yield() }
        await controller.requestAuthorizationFromUserAction()
        #expect(store.requestCount == 1)
        store.continuation?.resume()
        await first.value
        #expect(!controller.isRequesting)
    }

    // GIVEN denied or unavailable Health access for every type,
    // THEN local submission still saves and updates the store without requesting permissions.
    @Test(arguments: [HealthWriteAuthorization.denied, .unavailable])
    func localLoggingDoesNotNeedHealthAccess(status: HealthWriteAuthorization) throws {
        let client = FakeHealthKitClient(statuses: Dictionary(uniqueKeysWithValues:
            HealthWriteType.allCases.map { ($0, status) }))
        let controller = HealthAuthorizationController(client: client)
        controller.refreshAuthorization()
        let store = WateredStore()
        let handler = DrinkSubmissionHandler(store: store, analytics: NoOpAnalyticsClient())
        let entry = DrinkEntryFixture.make(drinkID: "water", drinkName: "Water",
            hydrationRule: .ratio(1), amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000))
        var saved = false
        try handler.submit(entry, method: .form, save: { _ in saved = true })
        #expect(saved)
        #expect(store.entries.count == 1)
        #expect(client.requestCount == 0)
    }
}

@MainActor
private final class AuthorizationStoreSpy: HealthAuthorizationStore {
    var isAvailable = true
    var statuses: [String: HKAuthorizationStatus] = [:]
    var shared: Set<HKSampleType> = []
    var read: Set<HKObjectType> = []
    var requestCount = 0
    var statusCount = 0
    var error: Error?
    var shouldSuspend = false
    var continuation: CheckedContinuation<Void, Never>?

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        statusCount += 1
        return statuses[type.identifier] ?? .notDetermined
    }

    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>) async throws {
        requestCount += 1
        shared = toShare
        self.read = read
        if shouldSuspend {
            await withCheckedContinuation { continuation = $0 }
        }
        if let error { throw error }
    }
}
