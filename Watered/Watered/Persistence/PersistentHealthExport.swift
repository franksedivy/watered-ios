import Foundation
import SwiftData

/// Device-local work, never a new drink provenance or a CloudKit synchronization record.
@Model
final class PersistentHealthExport {
    @Attribute(.unique) var identity: String
    var entryID: UUID
    var typeID: String
    var payload: Data?
    var policyVersion: String
    var syncVersion: Int = 1
    var operation: String = "upload"
    var status: String = "pending"
    var attemptCount: Int = 0
    var nextAttemptAt: Date?
    var failureCategory: String?
    /// Set durably before I/O; failure or missing acknowledgement never proves absence.
    var mayHaveWritten: Bool = false

    init(entryID: UUID, type: HealthWriteType, payload: Data?, invalid: Bool = false) {
        self.identity = HealthSampleSpecification.syncIdentifier(entryID: entryID, type: type)
        self.entryID = entryID
        self.typeID = type.rawValue
        self.payload = payload
        self.policyVersion = HealthSampleMapping.policyVersion
        if invalid {
            status = "invalid"
            failureCategory = "invalidPayload"
        }
    }
}

/// Absence means disabled. The boundary is audit context, never a query for backfill.
@Model
final class PersistentHealthSyncPreference {
    @Attribute(.unique) var id: String = "healthSync"
    var isEnabled: Bool = false
    var enabledAt: Date?

    init() {}
}
