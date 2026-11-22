import SwiftUI

/// Permission inspection only; grants do not enable export or change sync preferences.
struct HealthPermissionsView: View {
    let authorization: HealthAuthorizationController
    var analytics: any AnalyticsClient = NoOpAnalyticsClient()

    @State private var hasReportedOpen = false

    var body: some View {
        Form {
            HealthPermissionsSection(authorization: authorization, analytics: analytics)
        }
        .navigationTitle("Apple Health permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !hasReportedOpen else { return }
            hasReportedOpen = true
            analytics.track(.appleHealthPermissionsOpened)
        }
    }
}

private struct HealthPermissionsSection: View {
    let authorization: HealthAuthorizationController
    let analytics: any AnalyticsClient
    @State private var isShowingHealthGuidance = false
    @State private var healthGuidanceMessage = ""

    var body: some View {
        Section {
            permissionRow("Water", type: .water)
            permissionRow("Caffeine", type: .caffeine)
            permissionRow("Alcoholic beverages", type: .alcohol)

            Button(authorization.isRequesting ? "Requesting permissions…" : "Review permissions") {
                analytics.track(.appleHealthPermissionsReviewTapped)
                authorization.refreshAuthorization()
                let statuses = authorization.statuses.values
                if statuses.contains(.notDetermined) {
                    Task {
                        await authorization.requestAuthorizationFromUserAction()
                    }
                } else {
                    if statuses.contains(.unavailable) {
                        healthGuidanceMessage = "Apple Health is unavailable on this device. You can still log drinks in Watered."
                    } else if statuses.contains(.unknown) {
                        healthGuidanceMessage = "Watered couldn’t determine your permissions. Check Watered’s permissions in the Health app."
                    } else {
                        healthGuidanceMessage = "Open Health, tap your profile picture, then Apps → Watered to change which data Watered can write."
                    }
                    isShowingHealthGuidance = true
                }
            }
            .disabled(authorization.isRequesting)

            if let error = authorization.requestError {
                Label(errorMessage(for: error), systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Write permissions")
        } footer: {
            Text("Write permissions only. To change an existing choice, open Watered’s permissions in the Health app. Allowing access does not enable syncing. Watered does not yet send drinks to Apple Health.")
        }
        .alert("Apple Health permissions", isPresented: $isShowingHealthGuidance) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(healthGuidanceMessage)
        }
        .onAppear {
            authorization.refreshAuthorization()
        }
    }

    private func permissionRow(_ title: String, type: HealthWriteType) -> some View {
        LabeledContent {
            Text(statusLabel(for: authorization.statuses[type]))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
        }
    }

    private func statusLabel(for status: HealthWriteAuthorization?) -> String {
        switch status {
        case .authorized: return "Allowed"
        case .denied: return "Not allowed"
        case .notDetermined: return "Not requested"
        case .unavailable: return "Unavailable"
        case .unknown: return "Unknown"
        case nil: return "Checking…"
        }
    }

    private func errorMessage(for error: HealthAuthorizationError) -> String {
        switch error {
        case .unavailable:
            return "Apple Health is unavailable on this device. You can still log drinks in Watered."
        case .restricted:
            return "Health access is restricted on this device. Check device restrictions or contact its administrator. You can still log drinks in Watered."
        case .requestFailed:
            return "Couldn’t complete the permission request. Try again. You can still log drinks in Watered."
        case .requestInProgress:
            return "A permission request is already in progress. Finish that request before trying again."
        }
    }
}

#Preview("Mixed permissions") {
    NavigationStack {
        HealthPermissionsView(authorization: HealthAuthorizationController(
            client: FakeHealthKitClient(statuses: [
                .water: .authorized, .caffeine: .denied, .alcohol: .notDetermined
            ])
        ))
    }
}

#Preview("Unavailable") {
    NavigationStack {
        HealthPermissionsView(authorization: HealthAuthorizationController(
            client: FakeHealthKitClient()
        ))
    }
}
