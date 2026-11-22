import Foundation
import HealthKit
import Testing
@testable import Watered

@MainActor
struct HealthSampleMappingTests {
    private let allTypes = Set(HealthWriteType.allCases)
    private let id = UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")!
    private let loggedAt = Date(timeIntervalSince1970: 1_794_686_400)

    @Test func approvedCatalogueExamplesMapCapturedEstimates() throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        // Decision 001's reviewed recipe examples, not HealthKit conversion policy.
        for (drink, volume, variant, shots, abv, nonAlcoholic, water, caffeine, alcohol) in [
            ("still-water", 330.0, CaffeineVariant.regular, nil as Int?, nil as Double?, false, 330.0, 0.0 as Double?, nil as Double?),
            ("latte", 250, .regular, 2, nil, false, 225, 120, nil),
            ("latte", 250, .decaf, 2, nil, false, 225, 10, nil),
            ("latte", 250, .regular, 0, nil, false, 225, 0, nil),
            ("beer", 330, .regular, nil, 0.05, false, 306.9, 0, 13.0185 / 14),
            ("beer", 330, .regular, nil, nil, true, 320.1, 0, nil),
            ("cocktail", 200, .regular, nil, 0.10, false, 170, nil, 15.78 / 14)
        ] {
            let amount = DrinkAmount(value: volume, unit: .milliliters)
            let snapshot = try resolver.resolve(drinkID: drink, amount: amount,
                caffeineVariant: variant, shotCount: shots, isNonAlcoholic: nonAlcoholic, alcoholABV: abv)
            let entry = DrinkEntry(id: id, amount: amount, date: loggedAt, catalogueSnapshot: snapshot)
            let results = HealthSampleMapping.resolve(entry, eligibleTypes: allTypes)
            #expect(abs(try sample(results, .water).quantity - water) < 1e-9)
            if let caffeine, caffeine > 0 {
                #expect(try sample(results, .caffeine).quantity == caffeine)
            } else {
                #expect(results[.caffeine] == (caffeine == nil ? .unknown : .knownZero))
            }
            if let alcohol {
                #expect(abs(try sample(results, .alcohol).quantity - alcohol) < 1e-9)
            } else {
                #expect(results[.alcohol] == .unknown)
            }
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func everyInputUnitKeepsFullPrecision(unit: LiquidUnit) throws {
        let amount = DrinkAmount(value: 8, unit: unit)
        // Foundation conversion is platform behavior; 93% water and 14 g/count are Watered policy.
        let ml = amount.volume.converted(to: .milliliters).value
        let result = HealthSampleMapping.resolve(entry(amount: amount, water: ml * 0.93), eligibleTypes: allTypes)
        #expect(try sample(result, .water).quantity == ml * 0.93)
        #expect(try sample(result, .alcohol).quantity == ml * 0.05 * 0.789 / 14)
        #expect(try sample(result, .caffeine).quantity == 40)
    }

    @Test func unknownZeroAndNegativeGoalCreditRemainDistinct() throws {
        for hydration in [nil, -20.0, 0] {
            let unknown = HealthSampleMapping.resolve(entry(water: nil, caffeine: nil, abv: nil, hydration: hydration), eligibleTypes: allTypes)
            #expect(unknown.values.allSatisfy { $0 == .unknown })
            let known = HealthSampleMapping.resolve(entry(water: 0, caffeine: 0, abv: 0, hydration: hydration), eligibleTypes: allTypes)
            #expect(known.values.allSatisfy { $0 == .knownZero })
            let positive = HealthSampleMapping.resolve(entry(hydration: hydration), eligibleTypes: allTypes)
            #expect(try sample(positive, .water).quantity == 170)
        }
    }

    @Test func failuresAreIndependentAndBoundsAreNeverExactABV() throws {
        for invalid in [-1.0, .nan, .infinity] {
            let water = HealthSampleMapping.resolve(entry(water: invalid), eligibleTypes: allTypes)
            #expect(water[.water] == .invalid(.invalidQuantity))
            #expect(try sample(water, .caffeine).quantity == 40)
            _ = try sample(water, .alcohol)
            let caffeine = HealthSampleMapping.resolve(entry(caffeine: invalid), eligibleTypes: allTypes)
            #expect(caffeine[.caffeine] == .invalid(.invalidQuantity))
            _ = try sample(caffeine, .water)
            _ = try sample(caffeine, .alcohol)
            let alcohol = HealthSampleMapping.resolve(entry(abv: invalid), eligibleTypes: allTypes)
            #expect(alcohol[.alcohol] == .invalid(.invalidQuantity))
            _ = try sample(alcohol, .water)
            _ = try sample(alcohol, .caffeine)
        }
        #expect(HealthSampleMapping.resolve(entry(water: 201), eligibleTypes: allTypes)[.water] == .invalid(.invalidQuantity))
        #expect(HealthSampleMapping.resolve(entry(abv: nil, bound: 0.005), eligibleTypes: allTypes)[.alcohol] == .unknown)
        #expect(HealthSampleMapping.resolve(entry(abv: 0.005, bound: 0.005), eligibleTypes: allTypes)[.alcohol] == .invalid(.invalidQuantity))
        #expect(HealthSampleMapping.resolve(entry(abv: 1.01), eligibleTypes: allTypes)[.alcohol] == .invalid(.invalidQuantity))
    }

    @Test func invalidDatesAndVolumesFailEveryEligibleTypeWithoutSubstitution() {
        for value in [Double.nan, .infinity, -.infinity] {
            let result = HealthSampleMapping.resolve(entry(date: Date(timeIntervalSinceReferenceDate: value)), eligibleTypes: allTypes)
            #expect(result.values.allSatisfy { $0 == .invalid(.invalidDate) })
        }
        for value in [0.0, -1, .nan, .infinity] {
            let result = HealthSampleMapping.resolve(entry(amount: .init(value: value, unit: .milliliters)), eligibleTypes: allTypes)
            #expect(result.values.allSatisfy { $0 == .invalid(.invalidVolume) })
        }
    }

    @Test func callerEligibilityIsIndependentAndNeverInferredFromLoggedDate() throws {
        for mask in 0..<8 {
            let types = Set(HealthWriteType.allCases.enumerated().compactMap { index, type in
                mask & (1 << index) == 0 ? nil : type
            })
            let result = HealthSampleMapping.resolve(entry(), eligibleTypes: types)
            for type in HealthWriteType.allCases {
                if types.contains(type) { _ = try sample(result, type) }
                else { #expect(result[type] == .ineligible) }
            }
        }
    }

    @Test func frozenPayloadRoundTripAndRetryPreserveIdentityDatesAndContext() throws {
        let results = HealthSampleMapping.resolve(entry(), eligibleTypes: allTypes)
        var identities = Set<String>()
        for type in HealthWriteType.allCases {
            let original = try sample(results, type)
            let frozen = try JSONDecoder().decode(HealthSampleSpecification.self, from: JSONEncoder().encode(original))
            #expect(frozen == original)
            #expect(frozen.policyVersion == "health-export-v1")
            #expect(frozen.alcoholPolicyVersion == (type == .alcohol ? "alcohol-14g-v1" : nil))
            #expect(frozen.catalogueVersion == "historical")
            #expect(frozen.calculationVersion == "5")
            #expect(frozen.catalogueSchemaVersion == 6)
            #expect(frozen.syncIdentifier == "com.franksedivy.wateredapp-ios.drink.00112233-4455-6677-8899-aabbccddeeff.\(type.rawValue)")
            identities.insert(frozen.syncIdentifier)
            // Construction tests platform type/unit conversion and metadata, without a Health store.
            for _ in 0..<2 {
                let health = try HealthSampleFactory.makeSample(from: frozen)
                let unit: HKUnit = type == .water ? .literUnit(with: .milli) : type == .caffeine ? .gramUnit(with: .milli) : .count()
                let identifier: HKQuantityTypeIdentifier = type == .water ? .dietaryWater : type == .caffeine ? .dietaryCaffeine : .numberOfAlcoholicBeverages
                #expect(health.quantityType == HKQuantityType(identifier))
                #expect(abs(health.quantity.doubleValue(for: unit) - frozen.quantity) < 1e-9)
                #expect(health.startDate == loggedAt && health.endDate == loggedAt)
                #expect(health.metadata?[HKMetadataKeySyncIdentifier] as? String == frozen.syncIdentifier)
                #expect(health.metadata?[HKMetadataKeySyncVersion] as? Int == 1)
                #expect(health.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
            }
        }
        #expect(identities.count == 3)
        let renamed = HealthSampleMapping.resolve(entry(name: "Renamed retired drink"), eligibleTypes: allTypes)
        #expect(renamed == results)
        let other = HealthSampleMapping.resolve(entry(entryID: UUID()), eligibleTypes: allTypes)
        #expect(try sample(other, .water).syncIdentifier != sample(results, .water).syncIdentifier)
        // Parsing two timezone representations preserves the saved instant without global timezone mutation.
        let formatter = ISO8601DateFormatter()
        let utc = try #require(formatter.date(from: "2026-11-14T20:00:00Z"))
        let madrid = try #require(formatter.date(from: "2026-11-14T21:00:00+01:00"))
        #expect(HealthSampleMapping.resolve(entry(date: utc), eligibleTypes: allTypes)
            == HealthSampleMapping.resolve(entry(date: madrid), eligibleTypes: allTypes))
    }

    @Test func constructionRejectsCorruptOrUnsupportedFrozenPayloads() throws {
        let original = try sample(HealthSampleMapping.resolve(entry(), eligibleTypes: allTypes), .water)
        for (key, value) in [("policyVersion", "future" as Any), ("unit", "count"),
                             ("quantity", -1), ("syncVersion", 2), ("syncIdentifier", "other-entry")] {
            var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
            json[key] = value
            let decoded = try JSONDecoder().decode(HealthSampleSpecification.self, from: JSONSerialization.data(withJSONObject: json))
            #expect(throws: HealthSampleFactory.Failure.self) { try HealthSampleFactory.makeSample(from: decoded) }
        }
    }

    private func sample(_ results: [HealthWriteType: HealthSampleMapping.Result], _ type: HealthWriteType) throws -> HealthSampleSpecification {
        let result = try #require(results[type])
        guard case .sample(let spec) = result else {
            throw NSError(domain: "ExpectedSample", code: 1)
        }
        return spec
    }

    private func entry(amount: DrinkAmount = .init(value: 200, unit: .milliliters),
                       water: Double? = 170, caffeine: Double? = 40, abv: Double? = 0.05,
                       bound: Double? = nil, hydration: Double? = 0, date: Date? = nil,
                       name: String = "Retired saved recipe", entryID: UUID? = nil) -> DrinkEntry {
        DrinkEntry(id: entryID ?? id, amount: amount, date: date ?? loggedAt,
            createdAt: loggedAt.addingTimeInterval(86400), updatedAt: loggedAt.addingTimeInterval(86400),
            catalogueSnapshot: DrinkCatalogueSnapshot(drinkID: "retired-test", drinkName: name,
                caffeineVariant: .regular, shotCount: nil, hydrationContribution: hydration,
                caffeineAmount: caffeine, catalogueVersion: "historical", calculationVersion: "5",
                catalogueSchemaVersion: 6, waterAmount: water, alcoholABV: abv, alcoholABVUpperBound: bound))
    }
}
