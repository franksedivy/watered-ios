import Foundation

/// Cleanup needs stable identity only, never a valid quantity, current recipe or sample UUID.
nonisolated struct HealthDeletionTarget: Equatable, Sendable {
    let entryID: UUID
    let type: HealthWriteType
    let syncIdentifier: String

    var isValid: Bool {
        syncIdentifier == HealthSampleSpecification.syncIdentifier(entryID: entryID, type: type)
    }
}
