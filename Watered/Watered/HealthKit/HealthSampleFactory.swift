import HealthKit

/// Constructs samples only; never opens a Health store, requests permission or writes.
nonisolated enum HealthSampleFactory {
    enum Failure: Error {
        case unsupportedPolicy, invalidSpecification
    }

    static func makeSample(from specification: HealthSampleSpecification) throws -> HKQuantitySample {
        let spec = specification
        guard spec.policyVersion == "health-export-v1",
              spec.alcoholPolicyVersion == (spec.type == .alcohol ? "alcohol-14g-v1" : nil) else {
            throw Failure.unsupportedPolicy
        }
        let type: HKQuantityType
        let unit: HKUnit
        let expectedUnit: HealthSampleSpecification.Unit
        switch spec.type {
        case .water:
            type = HKQuantityType(.dietaryWater)
            unit = .literUnit(with: .milli)
            expectedUnit = .milliliters
        case .caffeine:
            type = HKQuantityType(.dietaryCaffeine)
            unit = .gramUnit(with: .milli)
            expectedUnit = .milligrams
        case .alcohol:
            type = HKQuantityType(.numberOfAlcoholicBeverages)
            unit = .count()
            expectedUnit = .count
        }
        guard spec.quantity.isFinite, spec.quantity > 0,
              spec.loggedAt.timeIntervalSinceReferenceDate.isFinite,
              spec.unit == expectedUnit, spec.syncVersion == 1,
              spec.syncIdentifier == HealthSampleSpecification.syncIdentifier(entryID: spec.entryID, type: spec.type) else {
            throw Failure.invalidSpecification
        }
        let manuallyEntered: Bool
        switch spec.source {
        case .manual: manuallyEntered = true
        }
        return HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: spec.quantity),
            start: spec.loggedAt, end: spec.loggedAt, metadata: [
                HKMetadataKeySyncIdentifier: spec.syncIdentifier,
                HKMetadataKeySyncVersion: spec.syncVersion,
                HKMetadataKeyWasUserEntered: manuallyEntered
            ])
    }
}
