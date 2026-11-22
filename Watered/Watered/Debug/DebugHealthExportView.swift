#if DEBUG
import SwiftUI
import SwiftData

/// Temporary inspection UI; all records stay on device and no action emits analytics.
struct DebugHealthExportView: View {
    let coordinator: HealthExportCoordinator
    @Environment(\.modelContext) private var modelContext
    @State private var enabled = false
    @State private var rows: [DebugHealthExportRow] = []
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var harness = coordinator.debugHarness
        Form {
            Section {
                Toggle("Enable test exports", isOn: Binding(get: { enabled }, set: setEnabled))
                Button("Retry now") { coordinator.retryNow() }
                Button("Refresh inspection") { refresh() }
                LabeledContent("Worker", value: coordinator.isProcessing ? "Processing" : "Idle")
                if coordinator.persistenceFailed {
                    Text("Export-state persistence failed. Pending work is retained; retry after resolving storage availability.")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Device verification only")
            } footer: {
                Text("Enabling writes new, permitted drink estimates to your real Apple Health store and resumes eligible pending work. It does not export old history. Disabling pauses new uploads; existing Health data remains. This preference persists across relaunches and builds sharing this store; turn it off when testing finishes. Use disposable test drinks. Health cleanup is not implemented yet (#110).")
            }

            Section {
                Picker("Next upload", selection: $harness.nextIntervention) {
                    ForEach(DebugHealthExportHarness.Intervention.allCases) { intervention in
                        Text(intervention.rawValue).tag(intervention)
                    }
                }
                .disabled(coordinator.isProcessing)
                Text(harness.lastIntervention).font(.footnote)
                if let type = harness.pausedType {
                    LabeledContent("Paused type", value: type.rawValue)
                    Text("HealthKit reported success. Local state is still inFlight. Stop the app with Xcode now to test recovery, or resume to record acknowledgement. Retry now cannot start another write while this one is paused.")
                    Button("Resume acknowledgement") { harness.resumeAcknowledgement() }
                }
            } header: {
                Text("One-shot intervention")
            } footer: {
                Text("Interventions reset on relaunch. The pause arms the next successful write; a failed write leaves it armed. Simulated failure occurs before HealthKit I/O and follows normal backoff. Neither option rewrites acknowledged records.")
            }

            Section {
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                if rows.isEmpty { Text("No export records") }
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(row.type) · \(row.status)").font(.headline)
                        Text("Operation: \(row.operation) · Attempts: \(row.attempts) · Version: \(row.version)")
                        Text("Possibly written: \(row.possibleWrite ? "yes" : "no")")
                        if let specification = row.specification {
                            Text("\(specification.quantity.formatted()) \(specification.unit.rawValue)")
                            Text(specification.loggedAt, format: .dateTime.year().month().day().hour().minute().second())
                        }
                        if let retry = row.retry {
                            Text("Next retry: \(retry.formatted(date: .omitted, time: .standard))")
                        }
                        if let failure = row.failure { Text("Failure category: \(failure)") }
                        Text(row.id).font(.caption2).textSelection(.enabled)
                    }
                    .font(.caption)
                }
            } header: {
                Text("Local export records (\(rows.count))")
            } footer: {
                Text("succeeded means a write was acknowledged, not that the sample still exists in Health. This inspector does not read Health data. Refresh after returning from Health to inspect current local state.")
            }
        }
        .navigationTitle("Verify HealthKit export")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
        .onChange(of: coordinator.isProcessing) { refresh() }
        .onChange(of: harness.isPaused) { refresh() }
    }

    private func setEnabled(_ value: Bool) {
        do {
            try coordinator.setEnabled(value)
            enabled = value
            errorMessage = nil
        } catch { errorMessage = "Could not save the export preference. It has not been changed." }
        refresh()
    }

    private func refresh() {
        do {
            let context = ModelContext(modelContext.container)
            enabled = try HealthExportPersistence.isEnabled(in: context)
            rows = try context.fetch(FetchDescriptor<PersistentHealthExport>()).map { DebugHealthExportRow($0) }
                .sorted { ($0.specification?.loggedAt ?? .distantPast) > ($1.specification?.loggedAt ?? .distantPast) }
        } catch { errorMessage = "Could not read export state. No data has been reset." }
    }
}

private struct DebugHealthExportRow: Identifiable {
    let id: String
    let type: String
    let status: String
    let operation: String
    let attempts: Int
    let version: Int
    let possibleWrite: Bool
    let retry: Date?
    let failure: String?
    let specification: HealthSampleSpecification?

    init(_ record: PersistentHealthExport) {
        id = record.identity
        type = record.typeID
        status = record.status
        operation = record.operation
        attempts = record.attemptCount
        version = record.syncVersion
        possibleWrite = record.mayHaveWritten
        retry = record.nextAttemptAt
        failure = record.failureCategory
        specification = record.payload.flatMap { try? JSONDecoder().decode(HealthSampleSpecification.self, from: $0) }
    }
}
#endif
