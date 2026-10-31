import Foundation
import Testing
@testable import Watered

@MainActor
struct HydrationSummaryViewDataTests {
    // Given a snapshot where total liquid and estimated hydration contribution differ,
    // when view data is created, then the main total uses raw liquid volume while
    // progress uses estimated hydration contribution.
    @Test func hydrationSummaryViewDataUsesHydrationProgressNotRawLiquidProgress() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 1000, unit: UnitVolume.milliliters),
            totalHydrationVolume: Measurement(value: 890, unit: UnitVolume.milliliters),
            goalVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            remainingHydrationVolume: Measurement(value: 1110, unit: UnitVolume.milliliters),
            drinkBreakdown: [
                DrinkBreakdown(
                    type: .juice,
                    totalVolume: Measurement(value: 1000, unit: UnitVolume.milliliters),
                    totalHydrationVolume: Measurement(value: 890, unit: UnitVolume.milliliters)
                )
            ]
        )

        let viewData = HydrationSummaryViewData(
            snapshot: snapshot,
            volumeFormatter: VolumeFormatter(),
            progressFormatter: ProgressFormatter()
        )

        #expect(viewData.totalText == "Total liquid: 1000 ml")
        #expect(viewData.goalText == "Hydration goal: 2000 ml")
        #expect(viewData.remainingText == "Remaining hydration: 1110 ml")
        #expect(viewData.drinkCountText == "Drinks logged: 1")
        #expect(viewData.progressText == "45%")
        #expect(viewData.actualProgressValue == 0.445)
        #expect(viewData.visualProgressValue == 0.445)
        #expect(viewData.drinkBreakdownRows.first?.consumedText == "1000 ml of Juice")
        #expect(viewData.drinkBreakdownRows.first?.hydrationImpactText == "Hydration impact: 89%")
    }

    // Given a snapshot with unknown estimated hydration contribution, when view
    // data is created, then hydration progress and remaining hydration are shown
    // as unknown rather than guessed.
    @Test func hydrationSummaryViewDataHandlesUnknownHydrationProgress() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 250, unit: UnitVolume.milliliters),
            totalHydrationVolume: nil,
            goalVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            remainingHydrationVolume: nil,
            drinkBreakdown: [
                DrinkBreakdown(
                    type: .other,
                    totalVolume: Measurement(value: 250, unit: UnitVolume.milliliters),
                    totalHydrationVolume: nil
                )
            ]
        )

        let viewData = HydrationSummaryViewData(
            snapshot: snapshot,
            volumeFormatter: VolumeFormatter(),
            progressFormatter: ProgressFormatter()
        )

        #expect(viewData.totalText == "Total liquid: 250 ml")
        #expect(viewData.remainingText == "Remaining hydration: Unknown")
        #expect(viewData.progressText == "Hydration progress unknown")
        #expect(viewData.actualProgressValue == nil)
        #expect(viewData.visualProgressValue == 0.0)
        #expect(viewData.drinkBreakdownRows.first?.consumedText == "250 ml of Other")
        #expect(viewData.drinkBreakdownRows.first?.hydrationImpactText == "Hydration impact: Unknown")
    }

    // Given a supported display unit, when summary view data is created, then volume
    // strings are formatted using that unit without changing the underlying model values.
    @Test func hydrationSummaryViewDataUsesDisplayUnit() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 1000, unit: UnitVolume.milliliters),
            totalHydrationVolume: Measurement(value: 1000, unit: UnitVolume.milliliters),
            goalVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            remainingHydrationVolume: Measurement(value: 1000, unit: UnitVolume.milliliters),
            drinkBreakdown: [
                DrinkBreakdown(
                    type: .water,
                    totalVolume: Measurement(value: 1000, unit: UnitVolume.milliliters),
                    totalHydrationVolume: Measurement(value: 1000, unit: UnitVolume.milliliters)
                )
            ]
        )

        let viewData = HydrationSummaryViewData(
            snapshot: snapshot,
            volumeFormatter: VolumeFormatter(locale: Locale(identifier: "en_GB")),
            progressFormatter: ProgressFormatter(),
            displayUnit: .usFluidOunces
        )

        #expect(viewData.totalText == "Total liquid: 34 US fl oz")
        #expect(viewData.goalText == "Hydration goal: 68 US fl oz")
        #expect(viewData.remainingText == "Remaining hydration: 34 US fl oz")
        #expect(viewData.drinkBreakdownRows.first?.consumedText == "34 US fl oz of Water")
        #expect(viewData.drinkBreakdownRows.first?.hydrationImpactText == "Hydration impact: 100%")
    }

    // Given a drink breakdown with negative hydration contribution, when view data is
    // created, then hydration impact is shown as a negative percentage.
    @Test func hydrationSummaryViewDataFormatsNegativeHydrationImpactPercentage() {
        let snapshot = HydrationSnapshot(
            drinkCount: 1,
            totalVolume: Measurement(value: 50, unit: UnitVolume.milliliters),
            totalHydrationVolume: Measurement(value: -150, unit: UnitVolume.milliliters),
            goalVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            remainingHydrationVolume: Measurement(value: 2150, unit: UnitVolume.milliliters),
            drinkBreakdown: [
                DrinkBreakdown(
                    type: .spirits,
                    totalVolume: Measurement(value: 50, unit: UnitVolume.milliliters),
                    totalHydrationVolume: Measurement(value: -150, unit: UnitVolume.milliliters)
                )
            ]
        )

        let viewData = HydrationSummaryViewData(
            snapshot: snapshot,
            volumeFormatter: VolumeFormatter(),
            progressFormatter: ProgressFormatter()
        )

        #expect(viewData.drinkBreakdownRows.first?.consumedText == "50 ml of Spirits")
        #expect(viewData.drinkBreakdownRows.first?.hydrationImpactText == "Hydration impact: -300%")
    }

    // Given drink breakdown rows with different hydration contribution ratios, when
    // summary view data is created, then each row receives the expected semantic
    // hydration impact style.
    @Test func hydrationSummaryViewDataAssignsHydrationImpactStyles() {
        let snapshot = HydrationSnapshot(
            drinkCount: 4,
            totalVolume: Measurement(value: 0, unit: UnitVolume.milliliters),
            totalHydrationVolume: Measurement(value: 0, unit: UnitVolume.milliliters),
            goalVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            remainingHydrationVolume: Measurement(value: 2000, unit: UnitVolume.milliliters),
            drinkBreakdown: [
                DrinkBreakdown(
                    type: .water,
                    totalVolume: Measurement(value: 100, unit: UnitVolume.milliliters),
                    totalHydrationVolume: Measurement(value: 100, unit: UnitVolume.milliliters)
                ),
                DrinkBreakdown(
                    type: .beer,
                    totalVolume: Measurement(value: 100, unit: UnitVolume.milliliters),
                    totalHydrationVolume: Measurement(value: 50, unit: UnitVolume.milliliters)
                ),
                DrinkBreakdown(
                    type: .wine,
                    totalVolume: Measurement(value: 100, unit: UnitVolume.milliliters),
                    totalHydrationVolume: Measurement(value: -30, unit: UnitVolume.milliliters)
                ),
                DrinkBreakdown(
                    type: .other,
                    totalVolume: Measurement(value: 100, unit: UnitVolume.milliliters),
                    totalHydrationVolume: nil
                )
            ]
        )

        let viewData = HydrationSummaryViewData(
            snapshot: snapshot,
            volumeFormatter: VolumeFormatter(),
            progressFormatter: ProgressFormatter()
        )

        #expect(viewData.drinkBreakdownRows[0].hydrationImpactStyle == .positive)
        #expect(viewData.drinkBreakdownRows[1].hydrationImpactStyle == .reduced)
        #expect(viewData.drinkBreakdownRows[2].hydrationImpactStyle == .negative)
        #expect(viewData.drinkBreakdownRows[3].hydrationImpactStyle == .unknown)
    }
    // GIVEN distinct drink IDs with the same captured name, when summary rows are
    // formatted, then their IDs stay distinct and the saved name keeps its casing.
    @Test func breakdownRowsPreserveCapturedNamesAndDistinctIdentities() {
        let drinkIDs = ["test-coffee-a", "test-coffee-b"]
        let entries = drinkIDs.map { drinkID in
            let snapshot = DrinkCatalogueSnapshot(
                drinkID: drinkID,
                drinkName: "Iced Coffee",
                caffeineVariant: .regular,
                shotCount: nil,
                hydrationContribution: 200,
                caffeineAmount: nil,
                catalogueVersion: "test-1",
                calculationVersion: "1"
            )

            return DrinkEntry(
                type: .coffee,
                amount: DrinkAmount(value: 250, unit: .milliliters),
                date: Date(timeIntervalSince1970: 1000),
                catalogueSnapshot: snapshot
            )
        }
        let tracker = HydrationTracker(
            entries: entries,
            dailyGoal: HydrationGoal(amount: DrinkAmount(value: 2000, unit: .milliliters))
        )
        let viewData = HydrationSummaryViewData(
            snapshot: tracker.snapshot,
            volumeFormatter: VolumeFormatter(locale: Locale(identifier: "en_GB")),
            progressFormatter: ProgressFormatter()
        )

        #expect(viewData.drinkBreakdownRows.map(\.drinkID) == drinkIDs)
        #expect(
            viewData.drinkBreakdownRows.map(\.consumedText) ==
            ["250 ml of Iced Coffee", "250 ml of Iced Coffee"]
        )
    }
}
