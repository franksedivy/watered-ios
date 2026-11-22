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

    /// Future export operations must use a fresh check, not cached presentation state.
    /// A grant alone never enables sync or makes a historical entry eligible.
    func currentAuthorization(for type: HealthWriteType) -> HealthWriteAuthorization {
        let status = client.authorization(for: type)
        statuses[type] = status
        return status
    }

    /// The only prompting entry point, for an explicit permission button in #111.
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
