import Foundation

/// Presents a snapshot of one type's upload work without retaining persistence models.
///
/// Counts describe local work and acknowledgements. They never infer the current
/// contents of Health; deletion work is presented separately by HealthCleanupSection.
struct HealthExportStatus {
    /// Acknowledged writes, including samples the person may since have removed in Health.
    var sent = 0
    /// Work awaiting an attempt or acknowledgement; an in-flight write may already exist in Health.
    var pending = 0
    /// Previously eligible work waiting for restored permission.
    var blocked = 0
    /// Temporary failures retained for retry with the original payload.
    var failed = 0
    /// Work that cannot be sent automatically, including unrecognised persisted states.
    var invalid = 0

    /// Separates mutually exclusive outcomes for the requested type and excludes cleanup.
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

    /// Applies the app preference to pending-work wording without rewriting recorded outcomes.
    /// Permission recovery and invalid-data guidance remain visible while uploads are paused.
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
