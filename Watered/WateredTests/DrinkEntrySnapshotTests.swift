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
    }

    // GIVEN an entry with an explicitly unknown captured contribution,
    // WHEN its contribution is read,
    // THEN it remains unknown rather than using the old drink-type rule.
    @Test func entryPreservesUnknownContribution() {
        let entry = makeEntry(contribution: nil)

        #expect(entry.hydrationContributionVolume == nil)
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
            calculationVersion: "1"
        )

        return DrinkEntry(
            type: .water,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date(timeIntervalSince1970: 1000),
            catalogueSnapshot: snapshot
        )
    }
}
