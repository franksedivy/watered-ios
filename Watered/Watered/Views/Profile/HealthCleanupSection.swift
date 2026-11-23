import SwiftUI
import SwiftData

/// Narrow deletion feedback; the broader export controls remain separate.
struct HealthCleanupSection: View {
    let coordinator: HealthExportCoordinator
    @Query(filter: #Predicate<PersistentHealthExport> { $0.operation == "delete" })
    private var records: [PersistentHealthExport]

    var body: some View {
        if !records.isEmpty {
            Section("Apple Health cleanup") {
                if records.contains(where: { $0.status == "authorizationBlocked" }) {
                    Text("Deleted from Watered. To remove its Apple Health data, restore permission or delete it in Health.")
                } else if records.contains(where: { $0.status == "invalid" }) {
                    Text("Deleted from Watered. Automatic Apple Health cleanup could not be completed. You can delete the remaining Watered samples in Health.")
                } else {
                    Text("Deleted from Watered. Apple Health cleanup is pending. Keep Watered open to finish.")
                }
                if coordinator.persistenceFailed {
                    Text("Cleanup progress could not be saved. It will retry when storage is available.")
                }
                Button("Retry now") { coordinator.retryNow() }
            }
        }
    }
}
