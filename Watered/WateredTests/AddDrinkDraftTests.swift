import Foundation
import Testing
@testable import Watered

@MainActor
struct AddDrinkDraftTests {
    // GIVEN selected catalogue values and a log date, when a draft is submitted,
    // THEN the new entry captures those values and the catalogue versions.
    @Test func draftCreatesEntryFromSelectedCatalogueValues() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let date = Date(timeIntervalSince1970: 1000)
        let draft = AddDrinkDraft(
            drinkID: "still-water",
            volumeValue: 330,
            unit: .milliliters
        )

        let entry = try draft.drinkEntry(using: resolver, date: date)

        #expect(entry.drinkID == "still-water")
        #expect(entry.amount.value == 330)
        #expect(entry.amount.unit == .milliliters)
        #expect(entry.loggedAt == date)
        #expect(entry.catalogueSnapshot.hydrationContribution == 330)
        #expect(entry.catalogueSnapshot.catalogueVersion == catalogue.version)
        #expect(entry.catalogueSnapshot.calculationVersion == DrinkCatalogueSnapshotResolver.calculationVersion)
    }

    // GIVEN a selected imperial volume, when a draft is resolved,
    // THEN the original unit is retained and estimates use the converted amount.
    @Test func draftPreservesSelectedUnit() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let draft = AddDrinkDraft(drinkID: "latte", volumeValue: 8, unit: .imperialFluidOunces)

        let entry = try draft.drinkEntry(using: resolver)
        let contribution = try #require(entry.catalogueSnapshot.hydrationContribution)
        let expected = VolumeCalculation.baseValue(from: entry.amount.volume) * 0.906

        #expect(entry.drinkID == "latte")
        #expect(entry.amount.value == 8)
        #expect(entry.amount.unit == .imperialFluidOunces)
        #expect(abs(contribution - expected) < 0.000001)
        #expect(entry.catalogueSnapshot.caffeineAmount == nil)
    }

    // GIVEN an unavailable selection, when the draft is submitted,
    // THEN resolution fails instead of inventing an entry or a fallback drink.
    @Test func draftRejectsUnavailableSelection() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let draft = AddDrinkDraft(drinkID: "missing-drink", volumeValue: 250, unit: .milliliters)

        #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
            try draft.drinkEntry(using: resolver)
        }
    }
}
