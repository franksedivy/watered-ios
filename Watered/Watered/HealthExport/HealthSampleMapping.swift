import Foundation

/// Frozen sample values staged by `HealthExportPersistence` for saving with an eligible new entry.
/// Retries reuse the persisted quantity, timestamp, policy context and sync identity without remapping.
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

    /// One type's mapping outcome; only `sample` contains a positive quantity to export.
    /// Ineligible types are not validated. Unknown and known-zero quantities remain distinct;
    /// invalid facts carry a failure rather than being substituted with zero or another estimate.
    enum Result: Equatable {
        case sample(HealthSampleSpecification)
        case ineligible, unknown, knownZero
        case invalid(Failure)
    }

    /// Maps captured facts independently for every write type without persistence or Health I/O.
    ///
    /// The caller supplies eligibility at entry creation; this never infers consent or backfill.
    /// Eligible types require a finite logged date and positive finite consumed volume before
    /// resolving quantities. Water and caffeine use saved estimates, not hydration goal credit;
    /// water cannot exceed consumed volume. Alcohol uses `AlcoholExportQuantity` policy.
    /// A quantity failure for one type does not prevent valid types from producing samples.
    ///
    /// `HealthExportPersistence` stages the results for the caller's drink transaction.
    /// Retries must reuse persisted specifications instead of calling this mapping again.
    ///
    /// - Parameters:
    ///   - entry: The logged amount, timestamp and captured facts to map without catalogue lookup.
    ///   - eligibleTypes: Types allowed for this new entry by the caller's export policy.
    /// - Returns: An outcome for every write type, including `.ineligible` for excluded types.
    ///   Validation failures are returned as `.invalid`, not thrown.
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
