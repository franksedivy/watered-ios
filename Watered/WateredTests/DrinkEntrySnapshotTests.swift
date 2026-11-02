//
//  DrinkEntrySnapshotTests.swift
//  Watered
//
//  Created by Frank Sedivy on 25/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkEntrySnapshotTests {
    // GIVEN an entry with a captured hydration contribution,
    // WHEN its contribution is read,
    // THEN it uses the captured value, including zero and negative values.
    @Test(arguments: [0.0, 125.0, -60.0])
    func entryUsesCapturedContribution(contribution: Double) throws {
        let entry = makeEntry(contribution: contribution)
        let volume = try #require(entry.hydrationContributionVolume)

        #expect(VolumeCalculation.baseValue(from: volume) == contribution)
        #expect(entry.hydrationContributionRatio == contribution / 250)
    }

    // GIVEN an entry with an explicitly unknown captured contribution,
    // WHEN its contribution is read,
    // THEN both the contribution and effective ratio remain unknown.
    @Test func entryPreservesUnknownContribution() {
        let entry = makeEntry(contribution: nil)

        #expect(entry.hydrationContributionVolume == nil)
        #expect(entry.hydrationContributionRatio == nil)
    }

    // GIVEN a captured contribution for one US fluid ounce, when its ratio is read,
    // THEN the amount is converted to the contribution's base unit before division.
    @Test func contributionRatioUsesMatchingVolumeUnits() throws {
        let original = makeEntry(contribution: 14.78676478125)
        let entry = DrinkEntry(
            amount: DrinkAmount(value: 1, unit: .usFluidOunces),
            date: original.loggedAt,
            catalogueSnapshot: original.catalogueSnapshot
        )

        let ratio = try #require(entry.hydrationContributionRatio)
        #expect(abs(ratio - 0.5) < 0.000001)
    }

    private func makeEntry(contribution: Double?) -> DrinkEntry {
        let snapshot = DrinkCatalogueSnapshot(
            drinkID: "test-drink",
            drinkName: "Test drink",
            caffeineVariant: .regular,
            shotCount: nil,
            hydrationContribution: contribution,
            caffeineAmount: nil,
            catalogueVersion: "test-1",
            calculationVersion: "1",
            catalogueSchemaVersion: 1
        )

        return DrinkEntry(
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000),
            catalogueSnapshot: snapshot
        )
    }
}
