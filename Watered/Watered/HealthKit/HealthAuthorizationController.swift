import Observation

/// App-owned permission presentation state, deliberately independent of sync preference.
@MainActor
@Observable
final class HealthAuthorizationController {
    private let client: any HealthKitClient
    private(set) var statuses: [HealthWriteType: HealthWriteAuthorization] = [:]
    private(set) var requestError: HealthAuthorizationError?
    private(set) var isRequesting = false

    init(client: any HealthKitClient) { self.client = client }

    /// Refresh on foreground entry; this can never display a permission sheet.
    func refreshAuthorization() {
        statuses = Dictionary(uniqueKeysWithValues: HealthWriteType.allCases.map {
            ($0, client.authorization(for: $0))
        })
    }

    /// Reads current permission and updates this type's presentation state without prompting.
    /// Export operations use fresh client checks, not this controller's cached presentation state.
    /// A grant alone never enables sync or makes a historical entry eligible.
    func currentAuthorization(for type: HealthWriteType) -> HealthWriteAuthorization {
        let status = client.authorization(for: type)
        statuses[type] = status
        return status
    }

    /// Requests permission from an explicit user action; overlapping calls return without prompting.
    /// Refreshes per-type status after success or failure and exposes a sanitized request error.
    func requestAuthorizationFromUserAction() async {
        guard !isRequesting else { return }
        isRequesting = true
        requestError = nil
        defer {
            refreshAuthorization()
            isRequesting = false
        }
        do {
            try await client.requestWriteAuthorization()
        } catch {
            requestError = error as? HealthAuthorizationError ?? .requestFailed
        }
        // Completion means the request finished, not that any individual type was granted.
    }
}
