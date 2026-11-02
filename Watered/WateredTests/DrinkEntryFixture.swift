import Foundation
@testable import Watered

/// Builds synthetic logged facts for tests independently of the bundled drink catalogue.
nonisolated enum DrinkEntryFixture {
    /// Creates a snapshot-backed entry using an explicit test rule.
    ///
    /// Rules supplied by tests describe their fixtures, not approved product estimates.
    /// Invalid fixture input deliberately fails setup rather than supplying guessed values.
    static func make(
        id: UUID = UUID(),
        drinkID: String,
        drinkName: String,
        hydrationRule: HydrationContributionRule,
        amount: DrinkAmount,
        date: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: DrinkEntrySource = .manual
    ) -> DrinkEntry {
        let contribution = try! DrinkEstimateCalculator.hydrationContribution(
            for: amount,
            rule: hydrationRule
        )
        let snapshot = DrinkCatalogueSnapshot(
            drinkID: drinkID,
            drinkName: drinkName,
            caffeineVariant: .regular,
            shotCount: nil,
            hydrationContribution: contribution,
            caffeineAmount: nil,
            catalogueVersion: "fixture-1",
            calculationVersion: "1",
            catalogueSchemaVersion: 1
        )
        return DrinkEntry(
            id: id,
            amount: amount,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: source,
            catalogueSnapshot: snapshot
        )
    }
}
