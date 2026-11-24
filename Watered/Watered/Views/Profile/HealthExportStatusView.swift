import SwiftUI
import SwiftData

/// Presents independent per-type outcomes away from the primary sync controls.
/// Fresh value snapshots describe acknowledged work, never inferred Health contents.
struct HealthExportStatusView: View {
    let coordinator: HealthExportCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// The committed preference determines whether pending upload wording is paused.
    @State private var enabled = false
    /// Retry stays unavailable until a complete snapshot can be read.
    @State private var loaded = false
    /// Value summaries refresh after worker completion and foreground entry.
    @State private var statuses: [HealthWriteType: HealthExportStatus] = [:]
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                    Button("Reload status") { refresh() }
                }
            }
            Section {
                ForEach(HealthWriteType.allCases, id: \.self) { type in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.displayName).font(.headline)
                        Text(statuses[type]?.message(enabled: enabled) ?? "Checking…")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("healthExportStatus-\(type.rawValue)")
                }
            }
            Section {
                if coordinator.persistenceFailed {
                    Text("Progress could not be saved. Pending work is retained. Retry when storage is available.")
                }
                Button("Retry now") { coordinator.retryNow() }
                    .disabled(coordinator.isProcessing || !loaded)
                    .accessibilityIdentifier("healthSyncRetry")
            }
        }
        .navigationTitle("Export status")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
        .onChange(of: coordinator.progressRevision) { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    /// Reads committed preference and work in a fresh context after foreground/worker changes.
    /// Failure disables retry and offers reload without altering the underlying records.
    private func refresh() {
        do {
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
            errorMessage = "Could not read export status. No data has been reset."
        }
    }
}
