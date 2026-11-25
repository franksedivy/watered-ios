import Foundation
import SwiftData

/// Device-local work, never a new drink provenance or a CloudKit synchronization record.
@Model
final class PersistentHealthExport {
    /// Stable entry/type sync identifier shared by upload retries and deletion targets.
    @Attribute(.unique) var identity: String
    var entryID: UUID
    var typeID: String
    /// Encoded frozen `HealthSampleSpecification`, reused for uploads without remapping.
    /// Invalid mappings may have no payload. Cleanup uses validated entry/type identity
    /// instead, so a missing or corrupt upload payload does not itself prevent deletion.
    var payload: Data?
    var policyVersion: String
    var syncVersion: Int = 1
    /// Current work: `upload`, or `delete` when a possibly written sample needs cleanup.
    var operation: String = "upload"
    /// State of the current operation, not of the drink or permission preference.
    /// `succeeded` records its acknowledgement once saved; for deletion it permits purge
    /// only when all remaining export records for the hidden drink also acknowledge cleanup.
    var status: String = "pending"
    var attemptCount: Int = 0
    var nextAttemptAt: Date?
    var failureCategory: String?
    /// Set durably before I/O; failure or missing acknowledgement never proves absence.
    var mayHaveWritten: Bool = false

    /// Creates an upload record with stable identity and the current mapping policy version.
    /// Does not decode or validate the payload, insert into a context, or save.
    /// - Parameters:
    ///   - entryID: The logged drink owning this work.
    ///   - type: The independently exported Health quantity type.
    ///   - payload: Encoded frozen sample values, or nil for an invalid mapping.
    ///   - invalid: Starts in `invalid` with `invalidPayload` failure instead of `pending`;
    ///     this flag records the caller's mapping outcome, not a validation performed here.
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
