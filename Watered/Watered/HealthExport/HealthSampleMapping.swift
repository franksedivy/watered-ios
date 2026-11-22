import Foundation

/// Frozen values for #109 to persist with an eligible new entry and reuse without remapping.
nonisolated struct HealthSampleSpecification: Codable, Equatable {
    enum Unit: String, Codable {
        case milliliters, milligrams, count
    }

    let entryID: UUID
    let type: HealthWriteType
    let quantity: Double
    let unit: Unit
    let loggedAt: Date
    let source: DrinkEntrySource
    let policyVersion: String
    let alcoholPolicyVersion: String?
    let catalogueVersion: String
    let calculationVersion: String
    let catalogueSchemaVersion: Int?
    let syncIdentifier: String
    let syncVersion: Int

    static func syncIdentifier(entryID: UUID, type: HealthWriteType) -> String {
        "com.franksedivy.wateredapp-ios.drink.\(entryID.uuidString.lowercased()).\(type.rawValue)"
    }
}

/// Pure mapping of captured facts, independent of catalogue lookup and HealthKit I/O.
nonisolated enum HealthSampleMapping {
    static let policyVersion = "health-export-v1"

    enum Failure: Error, Equatable {
        case invalidDate, invalidVolume, invalidQuantity
    }

    enum Result: Equatable {
        case sample(HealthSampleSpecification)
        case ineligible, unknown, knownZero
        case invalid(Failure)
    }

    /// The caller supplies types eligible at entry creation; this never infers consent or backfill.
    /// Retry the frozen specifications, not this function. Durable capture belongs to #109.
    static func resolve(_ entry: DrinkEntry, eligibleTypes: Set<HealthWriteType>) -> [HealthWriteType: Result] {
        Dictionary(uniqueKeysWithValues: HealthWriteType.allCases.map { type in
            (type, eligibleTypes.contains(type) ? resolve(entry, type: type) : .ineligible)
        })
    }

    private static func resolve(_ entry: DrinkEntry, type: HealthWriteType) -> Result {
        guard entry.loggedAt.timeIntervalSinceReferenceDate.isFinite else { return .invalid(.invalidDate) }
        let volume = VolumeCalculation.baseValue(from: entry.amount.volume)
        guard volume.isFinite, volume > 0 else { return .invalid(.invalidVolume) }
        let snapshot = entry.catalogueSnapshot
        let quantity: Double
        let unit: HealthSampleSpecification.Unit
        switch type {
        case .water, .caffeine:
            guard let saved = type == .water ? snapshot.waterAmount : snapshot.caffeineAmount else { return .unknown }
            guard saved.isFinite, saved >= 0, type != .water || saved <= volume else {
                return .invalid(.invalidQuantity)
            }
            guard saved > 0 else { return .knownZero }
            quantity = saved
            unit = type == .water ? .milliliters : .milligrams
        case .alcohol:
            switch AlcoholExportQuantity.resolve(entry) {
            case .standardDrinks(let count): quantity = count
            case .knownZero: return .knownZero
            case .unknown: return .unknown
            case .invalid: return .invalid(.invalidQuantity)
            }
            unit = .count
        }
        return .sample(HealthSampleSpecification(
            entryID: entry.id, type: type, quantity: quantity, unit: unit,
            loggedAt: entry.loggedAt, source: entry.source, policyVersion: policyVersion,
            alcoholPolicyVersion: type == .alcohol ? AlcoholExportQuantity.policyVersion : nil,
            catalogueVersion: snapshot.catalogueVersion, calculationVersion: snapshot.calculationVersion,
            catalogueSchemaVersion: snapshot.catalogueSchemaVersion,
            syncIdentifier: HealthSampleSpecification.syncIdentifier(entryID: entry.id, type: type),
            syncVersion: 1
        ))
    }
}
