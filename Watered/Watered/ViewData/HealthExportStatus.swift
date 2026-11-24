import Foundation

/// Counts acknowledged actions, never inferred contents of the Health store.
struct HealthExportStatus {
    var sent = 0
    var pending = 0
    var blocked = 0
    var failed = 0
    var invalid = 0

    init(records: [PersistentHealthExport], type: HealthWriteType) {
        for record in records where record.typeID == type.rawValue && record.operation == "upload" {
            switch record.status {
            case "succeeded": sent += 1
            case "authorizationBlocked": blocked += 1
            case "invalid": invalid += 1
            case "pending" where record.failureCategory != nil: failed += 1
            case "pending", "inFlight": pending += 1
            default: invalid += 1
            }
        }
    }

    func message(enabled: Bool) -> String {
        var parts: [String] = []
        if sent > 0 { parts.append("Sent to Apple Health: \(sent)") }
        if pending > 0 { parts.append("\(enabled ? "Pending" : "Paused"): \(pending)") }
        if blocked > 0 { parts.append("Needs permission: \(blocked)") }
        if failed > 0 { parts.append("\(enabled ? "Waiting to retry" : "Retry paused"): \(failed)") }
        if invalid > 0 { parts.append("Could not send: \(invalid)") }
        return parts.isEmpty ? "No eligible exports" : parts.joined(separator: ". ")
    }
}
