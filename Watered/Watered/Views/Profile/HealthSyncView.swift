import SwiftUI
import SwiftData

/// Presents opt-in, independent permissions and durable export progress in Profile.
///
/// Preference changes commit immediately through the existing coordinator, independently
/// of Profile's goal draft. Opening, toggling and retrying never request authorization;
/// the embedded permission section owns the explicit permission action.
/// Additional controls appear only when enabled; information and off-state cleanup
/// recovery remain accessible through the final Privacy & information row.
struct HealthSyncView: View {
    let authorization: HealthAuthorizationController
    let coordinator: HealthExportCoordinator
    var analytics: any AnalyticsClient = NoOpAnalyticsClient()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// Last successfully read or committed preference, never inferred from Health grants.
    @State private var enabled = false
    /// Prevents edits until the persisted preference can be read.
    @State private var loaded = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Sync with Apple Health", isOn: Binding(get: { enabled }, set: setEnabled))
                    .disabled(!loaded)
                    .accessibilityIdentifier("healthSyncToggle")
                    .accessibilityHint("Sends new eligible drink estimates for the types you allow. Does not request permission.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                    Button("Reload status") { refresh() }
                }
            }

            if enabled {
                HealthPermissionsSection(authorization: authorization, analytics: analytics)
                Section {
                    NavigationLink("Export status") {
                        HealthExportStatusView(coordinator: coordinator)
                    }
                    .accessibilityIdentifier("healthExportStatusLink")
                }
                HealthCleanupSection(coordinator: coordinator)
            }

            Section {
                NavigationLink("Privacy & information") {
                    HealthSyncInformationView(authorization: authorization, coordinator: coordinator, analytics: analytics)
                }
                .accessibilityIdentifier("healthSyncInformation")
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
        .onChange(of: coordinator.progressRevision) { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    /// Updates the displayed choice only after persistence succeeds; a failed save retains it.
    /// The coordinator decides whether eligible uploads or cleanup can run.
    private func setEnabled(_ value: Bool) {
        do {
            try coordinator.setEnabled(value, analytics: analytics)
            enabled = value
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Could not save your sync preference. It has not changed."
        }
    }

    /// Reads a consistent presentation snapshot without touching Profile's pending settings.
    /// A failed read disables preference edits and offers recovery without resetting storage.
    private func refresh() {
        do {
            // Read committed preferences without retaining a stale model from another context.
            let context = ModelContext(modelContext.container)
            let preference = try HealthExportPersistence.isEnabled(in: context)
            enabled = preference
            loaded = true
            errorMessage = nil
        } catch {
            loaded = false
            errorMessage = "Could not read sync status. No data has been reset."
        }
    }
}

extension HealthWriteType {
    /// User-facing quantity label; persisted type identifiers remain unchanged.
    var displayName: String {
        switch self {
        case .water: "Water"
        case .caffeine: "Caffeine"
        case .alcohol: "Alcoholic beverages"
        }
    }
}
