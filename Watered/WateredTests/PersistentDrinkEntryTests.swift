import Foundation
import Testing
@testable import Watered

@MainActor
struct PersistentDrinkEntryTests {
    // GIVEN an entry with captured facts and timestamps, when a storage row is created,
    // THEN the original values are stored without changing units or provenance.
    @Test func persistentEntryStoresCapturedValues() {
        let entry = makeEntry()
        let record = PersistentDrinkEntry(drinkEntry: entry)

        #expect(record.id == entry.id)
        #expect(record.catalogueDrinkID == "missing-from-current-catalogue")
        #expect(record.catalogueDrinkName == "Retained drink")
        #expect(record.volumeValue == 8)
        #expect(record.unitID == "imperialFluidOunces")
        #expect(record.loggedAt == entry.loggedAt)
        #expect(record.createdAt == entry.createdAt)
        #expect(record.updatedAt == entry.updatedAt)
        #expect(record.source == "manual")
    }

    // GIVEN a complete saved drink absent from the current catalogue, when it is restored,
    // THEN its identity, metadata and captured facts remain readable without a lookup.
    @Test func persistentEntryRestoresUnavailableDrinkFromStoredFacts() throws {
        let entry = makeEntry()
        let record = PersistentDrinkEntry(drinkEntry: entry)

        let restored = try #require(record.drinkEntry())

        #expect(restored.id == entry.id)
        #expect(restored.drinkID == entry.drinkID)
        #expect(restored.displayName == "Retained drink")
        #expect(restored.amount.value == 8)
        #expect(restored.amount.unit == .imperialFluidOunces)
        #expect(restored.loggedAt == entry.loggedAt)
        #expect(restored.createdAt == entry.createdAt)
        #expect(restored.updatedAt == entry.updatedAt)
        #expect(restored.source == entry.source)
        #expect(restored.catalogueSnapshot == entry.catalogueSnapshot)
        #expect(restored.catalogueSnapshot.catalogueSchemaVersion == nil)
    }

    // GIVEN incomplete or invalid saved metadata, when restoration is attempted,
    // THEN it fails rather than guessing identity, preparation, versions or units.
    @Test(arguments: ["id", "name", "variant", "catalogueVersion", "calculationVersion", "unit", "source"])
    func persistentEntryRejectsIncompleteMetadata(field: String) {
        let record = PersistentDrinkEntry(drinkEntry: makeEntry())
        switch field {
        case "id": record.catalogueDrinkID = nil
        case "name": record.catalogueDrinkName = nil
        case "variant": record.caffeineVariantID = "unsupported"
        case "catalogueVersion": record.catalogueVersion = nil
        case "calculationVersion": record.calculationVersion = nil
        case "unit": record.unitID = "unsupported"
        case "source": record.source = "unsupported"
        default: Issue.record("Unexpected test field")
        }

        #expect(record.drinkEntry() == nil)
    }

    // GIVEN zero or unknown saved estimates, when a row is restored,
    // THEN zero remains a known value and unknown remains nil.
    @Test func persistentEntryPreservesZeroAndUnknownEstimates() throws {
        let record = PersistentDrinkEntry(drinkEntry: makeEntry())
        record.hydrationContribution = nil
        record.caffeineAmount = 0

        let restored = try #require(record.drinkEntry())

        #expect(restored.hydrationContributionVolume == nil)
        #expect(restored.catalogueSnapshot.caffeineAmount == 0)
    }

    @Test func persistentEntryPreservesZeroShotsAndRejectsNegativeShots() throws {
        let record = PersistentDrinkEntry(drinkEntry: makeEntry())
        record.shotCount = 0
        let restored = try #require(record.drinkEntry())
        #expect(restored.catalogueSnapshot.shotCount == 0)
        record.shotCount = -1
        #expect(record.drinkEntry() == nil)
    }

    private func makeEntry() -> DrinkEntry {
        let snapshot = DrinkCatalogueSnapshot(
            drinkID: "missing-from-current-catalogue",
            drinkName: "Retained drink",
            caffeineVariant: .decaf,
            shotCount: 2,
            hydrationContribution: -60,
            caffeineAmount: nil,
            catalogueVersion: "old-content",
            calculationVersion: "old-calculation",
            catalogueSchemaVersion: nil
        )
        return DrinkEntry(
            amount: DrinkAmount(value: 8, unit: .imperialFluidOunces),
            date: Date(timeIntervalSince1970: 1000),
            createdAt: Date(timeIntervalSince1970: 2000),
            updatedAt: Date(timeIntervalSince1970: 3000),
            catalogueSnapshot: snapshot
        )
    }
}
