import SwiftUI
import SwiftData

/// Presents opt-in, independent permissions and durable export progress in Profile.
///
/// Preference changes commit immediately through the existing coordinator, independently
/// of Profile's goal draft. Opening, toggling and retrying never request authorization;
/// the embedded permission section owns the explicit permission action.
struct HealthSyncView: View {
    let authorization: HealthAuthorizationController
    let coordinator: HealthExportCoordinator
    var analytics: any AnalyticsClient = NoOpAnalyticsClient()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// Last successfully read or committed preference, never inferred from Health grants.
    @State private var enabled = false
    /// Prevents edits until the persisted preference and progress can be read together.
    @State private var loaded = false
    /// Value snapshots refreshed after worker activity and foreground return.
    @State private var statuses: [HealthWriteType: HealthExportStatus] = [:]
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Sync with Apple Health", isOn: Binding(get: { enabled }, set: setEnabled))
                    .disabled(!loaded)
                    .accessibilityIdentifier("healthSyncToggle")
                    .accessibilityHint("Sends new eligible drink estimates for the types you allow. Does not request permission.")
                Text("Optional, one-way sharing. Watered works without it and never reads your Health data.")
                Text("Water is estimated water content, not drink volume or hydration credit. Caffeine is the saved estimate. Alcohol is an estimated number of 14 g standard drinks, based on volume and strength. Unknown or zero amounts are not sent.")
            } header: {
                Text("What is shared")
            } footer: {
                Text("Enable sync and allow each type below. Only drinks added while both are enabled are eligible, including newly added backdated drinks. Existing history and gaps are not filled in later.")
            }

            HealthPermissionsSection(authorization: authorization, analytics: analytics)

            Section {
                Text(!loaded ? "Checking sync status" : (enabled ? "Sync enabled" : "Sync disabled"))
                    .accessibilityIdentifier("healthSyncStatus")
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                    Button("Reload status") { refresh() }
                }
                if coordinator.persistenceFailed {
                    Text("Progress could not be saved. Pending work is retained. Retry when storage is available.")
                }
                ForEach(HealthWriteType.allCases, id: \.self) { type in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.displayName).font(.headline)
                        Text(statuses[type]?.message(enabled: enabled) ?? "Checking…")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("healthExportStatus-\(type.rawValue)")
                }
                Button("Retry now") { coordinator.retryNow() }
                    .disabled(coordinator.isProcessing || !loaded)
                    .accessibilityIdentifier("healthSyncRetry")
                Text("Retry sends eligible pending work when sync and permission allow it. Cleanup retries even with sync off. Keep Watered open to let work finish.")
                    .font(.footnote)
                Text("If permission is needed, use Review permissions. Estimates that could not be sent cannot be repaired by retrying; your drink remains saved in Watered.")
                    .font(.footnote)
            } header: {
                Text("Export status")
            } footer: {
                Text("Sent to Apple Health means Health acknowledged the write. It does not mean the sample is still there. Watered does not check for or replace acknowledged samples you delete in Health.")
            }

            HealthCleanupSection(coordinator: coordinator)

            Section("Turning sync off and deleting drinks") {
                Text("Turning sync off pauses pending uploads and leaves existing Health data in place. An upload already in progress may finish. Turning it back on resumes eligible pending work, without exporting missed history or older entries for newly allowed types.")
                Text("Deleting a drink hides it from Watered after saving the deletion and requests removal of its Watered-created Health samples. Cleanup continues with sync off. If cleanup is delayed, drink details stay on this device until it finishes. Restore permission to complete blocked cleanup; deleting samples manually in Health does not confirm cleanup to Watered.")
            }
            Section("Privacy") {
                Text("Your drink history and export progress are stored on this device. Watered does not send them to our servers or use them for advertising. Health data is handled by Apple according to your Health and iCloud settings.")
                Text("Watered requests write access only for water, caffeine and alcoholic beverages. You can change each permission in Health at any time. Local drink logging remains available.")
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
            try coordinator.setEnabled(value)
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
            // Fresh context observes worker acknowledgements without retaining stale models.
            let context = ModelContext(modelContext.container)
            let preference = try HealthExportPersistence.isEnabled(in: context)
            let records = try context.fetch(FetchDescriptor<PersistentHealthExport>())
            statuses = Dictionary(uniqueKeysWithValues: HealthWriteType.allCases.map {
                ($0, HealthExportStatus(records: records, type: $0))
            })
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
