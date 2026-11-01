import Foundation
import Testing
@testable import Watered

@MainActor
struct HydrationTrackerTests {
    // MARK: - Totals and Breakdown

    // Given multiple drink entries, when the tracker calculates total volume,
    // then it sums the raw consumed liquid volume across entries.
    @Test func hydrationTrackerCalculatesTotalVolume() {
        let water = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let tea = DrinkEntryFixture.make(
            drinkID: "test-tea",
            drinkName: "Tea",
            hydrationRule: .ratio(0.99),
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [water, tea],
            dailyGoal: goal
        )

        let total = tracker.totalVolume.converted(to: .milliliters)

        #expect(total.value == 550)
    }

    // Given entries with captured contributions, when the tracker calculates hydration,
    // then it sums the saved estimates without consulting current catalogue rules.
    @Test func hydrationTrackerCalculatesTotalHydrationVolume() {
        let water = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let juice = DrinkEntryFixture.make(
            drinkID: "test-juice",
            drinkName: "Juice",
            hydrationRule: .ratio(0.89),
            amount: DrinkAmount(value: 100, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [water, juice],
            dailyGoal: goal
        )

        let totalWater = tracker.totalHydrationVolume?.converted(to: .milliliters)

        #expect(totalWater?.value == 339)
    }

    // Given a hydration goal and drinks with known contribution rules, when the
    // tracker calculates remaining hydration, then it subtracts estimated hydration
    // from the goal.
    @Test func hydrationTrackerCalculatesRemainingHydrationVolume() {
        let juice = DrinkEntryFixture.make(
            drinkID: "test-juice",
            drinkName: "Juice",
            hydrationRule: .ratio(0.89),
            amount: DrinkAmount(value: 100, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 500, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [juice],
            dailyGoal: goal
        )

        let remainingHydration = tracker.remainingHydrationVolume?.converted(to: .milliliters)

        #expect(remainingHydration?.value == 411)
    }

    // Given any entry with unknown hydration contribution, when the tracker
    // calculates hydration totals, then hydration and remaining values are unknown.
    @Test func hydrationTrackerHydrationContributionVolumeIsUnknownWhenEntryHydrationContributionVolumeIsUnknown() {
        let other = DrinkEntryFixture.make(
            drinkID: "test-other",
            drinkName: "Other",
            hydrationRule: .unknown,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [other],
            dailyGoal: goal
        )

        #expect(tracker.totalHydrationVolume == nil)
        #expect(tracker.remainingHydrationVolume == nil)
    }

    // Given a tracker with one drink entry and a goal, when it creates a snapshot,
    // then the snapshot captures totals, goal progress, and drink breakdown values.
    @Test func hydrationTrackerCreatesSnapshot() {
        let water = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 500, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [water],
            dailyGoal: goal
        )

        let snapshot = tracker.snapshot
        let breakdown = snapshot.drinkBreakdown
        let firstBreakdown = breakdown.first
        let firstBreakdownTotal = firstBreakdown?.totalVolume.converted(to: .milliliters)

        #expect(snapshot.drinkCount == 1)
        #expect(snapshot.totalVolume.converted(to: .milliliters).value == 500)
        #expect(snapshot.totalHydrationVolume?.converted(to: .milliliters).value == 500)
        #expect(snapshot.goalVolume.converted(to: .milliliters).value == 2000)
        #expect(snapshot.remainingHydrationVolume?.converted(to: .milliliters).value == 1500)
        #expect(breakdown.count == 1)
        #expect(firstBreakdown?.drinkID == "still-water")
        #expect(firstBreakdownTotal?.value == 500)
    }

    // Given multiple drink entries, including two entries with the same drink identity,
    // when the tracker creates a drink breakdown, then entries of the same identity are
    // grouped together and their raw liquid volumes are added.
    @Test func hydrationTrackerCreatesDrinkBreakdownByIdentity() {
        let firstWater = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let secondWater = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 500, unit: .milliliters),
            date: Date()
        )

        let juice = DrinkEntryFixture.make(
            drinkID: "test-juice",
            drinkName: "Juice",
            hydrationRule: .ratio(0.89),
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [firstWater, secondWater, juice],
            dailyGoal: goal
        )

        let breakdown = tracker.drinkBreakdown
        let waterBreakdown = breakdown.first { drinkBreakdown in
            drinkBreakdown.drinkID == "still-water"
        }
        let juiceBreakdown = breakdown.first { drinkBreakdown in
            drinkBreakdown.drinkID == "test-juice"
        }

        let waterTotal = waterBreakdown?.totalVolume.converted(to: .milliliters)
        let juiceTotal = juiceBreakdown?.totalVolume.converted(to: .milliliters)

        #expect(breakdown.count == 2)
        #expect(waterTotal?.value == 750)
        #expect(juiceTotal?.value == 300)
    }

    // Given water entries in the drink log, when the tracker creates a drink breakdown,
    // then the water breakdown reports the same value for raw liquid volume and
    // estimated hydration volume.
    @Test func hydrationTrackerDrinkBreakdownIncludesHydrationVolumeForWater() {
        let firstWater = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )
        let secondWater = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 500, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [firstWater, secondWater],
            dailyGoal: goal
        )
        let breakdown = tracker.drinkBreakdown
        let waterBreakdown = breakdown.first { drinkBreakdown in
            drinkBreakdown.drinkID == "still-water"
        }

        let rawTotal = waterBreakdown?.totalVolume.converted(to: .milliliters)
        let hydrationTotal = waterBreakdown?.totalHydrationVolume?.converted(to: .milliliters)

        #expect(rawTotal?.value == 750)
        #expect(hydrationTotal?.value == 750)
    }

    // Given a juice entry in the drink log, when the tracker creates a drink breakdown,
    // then the juice breakdown reports full raw liquid volume and a lower estimated
    // hydration volume based on the juice water-content ratio.
    @Test func hydrationTrackerDrinkBreakdownIncludesHydrationVolumeForJuice() {
        let juice = DrinkEntryFixture.make(
            drinkID: "test-juice",
            drinkName: "Juice",
            hydrationRule: .ratio(0.89),
            amount: DrinkAmount(value: 300, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [juice],
            dailyGoal: goal
        )
        let breakdown = tracker.drinkBreakdown
        let juiceBreakdown = breakdown.first { drinkBreakdown in
            drinkBreakdown.drinkID == "test-juice"
        }

        let rawTotal = juiceBreakdown?.totalVolume.converted(to: .milliliters)
        let hydrationTotal = juiceBreakdown?.totalHydrationVolume?.converted(to: .milliliters)

        #expect(rawTotal?.value == 300)
        #expect(hydrationTotal?.value == 267)
    }

    // Given a drink entry of type Other, when the tracker creates a drink breakdown,
    // then the raw liquid volume is still known but estimated hydration volume
    // remains unknown.
    @Test func hydrationTrackerDrinkBreakdownIncludesTotalVolumeForOther() {
        let other = DrinkEntryFixture.make(
            drinkID: "test-other",
            drinkName: "Other",
            hydrationRule: .unknown,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [other],
            dailyGoal: goal
        )

        let breakdown = tracker.drinkBreakdown
        let otherBreakdown = breakdown.first { drinkBreakdown in
            drinkBreakdown.drinkID == "test-other"
        }

        let rawTotal = otherBreakdown?.totalVolume.converted(to: .milliliters)

        #expect(rawTotal?.value == 250)
        #expect(otherBreakdown?.totalHydrationVolume == nil)
    }

    // Given drink entries for only one identity, when the tracker creates a drink
    // breakdown, then only that logged identity appears in the result.
    @Test func hydrationTrackerDrinkBreakdownIncludesOnlyLoggedIdentities() {
        let water = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )

        let tracker = HydrationTracker(
            entries: [water],
            dailyGoal: goal
        )

        let breakdown = tracker.drinkBreakdown

        #expect(breakdown.count == 1)
        #expect(breakdown.first?.drinkID == "still-water")
    }

    // Given entries with captured contributions, when the total is calculated,
    // then the saved values are summed in the base volume unit.
    @Test func hydrationTrackerSumsCapturedContributionVolumes() {
        let water = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )
        let juice = DrinkEntryFixture.make(
            drinkID: "test-juice",
            drinkName: "Juice",
            hydrationRule: .ratio(0.89),
            amount: DrinkAmount(value: 100, unit: .milliliters),
            date: Date()
        )
        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )
        let tracker = HydrationTracker(
            entries: [water, juice],
            dailyGoal: goal
        )
        let totalHydration = tracker.totalHydrationVolume?.converted(to: .milliliters)

        #expect(totalHydration?.value == 339)
    }

    // Given water, beer, and wine entries, when the tracker calculates totals,
    // then raw liquid includes every drink while hydration sums their saved contributions.
    @Test func hydrationTrackerCountsAlcoholInRawTotalAndHydrationContribution() {
        let water = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 500, unit: .milliliters),
            date: Date()
        )
        let beer = DrinkEntryFixture.make(
            drinkID: "test-beer",
            drinkName: "Beer",
            hydrationRule: .alcohol(defaultABV: 0.05),
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date()
        )
        let wine = DrinkEntryFixture.make(
            drinkID: "test-wine",
            drinkName: "Wine",
            hydrationRule: .alcohol(defaultABV: 0.13),
            amount: DrinkAmount(value: 150, unit: .milliliters),
            date: Date()
        )
        let goal = HydrationGoal(
            amount: DrinkAmount(value: 2000, unit: .milliliters)
        )
        let tracker = HydrationTracker(
            entries: [water, beer, wine],
            dailyGoal: goal
        )

        let totalVolume = tracker.totalVolume.converted(to: .milliliters)
        let totalHydrationVolume = tracker.totalHydrationVolume?.converted(to: .milliliters)

        #expect(totalVolume.value == 980)
        #expect(totalHydrationVolume?.value == 620)
    }

    // Given a spirits entry with negative hydration contribution, when remaining
    // hydration is calculated, then the remaining amount increases above the goal.
    @Test func hydrationTrackerNegativeAlcoholContributionIncreasesRemainingHydration() {
        let spirits = DrinkEntryFixture.make(
            drinkID: "test-spirits",
            drinkName: "Spirits",
            hydrationRule: .alcohol(defaultABV: 0.40),
            amount: DrinkAmount(value: 25, unit: .milliliters),
            date: Date()
        )
        let goal = HydrationGoal(
            amount: DrinkAmount(value: 500, unit: .milliliters)
        )
        let tracker = HydrationTracker(
            entries: [spirits],
            dailyGoal: goal
        )

        let totalHydrationVolume = tracker.totalHydrationVolume?.converted(to: .milliliters)
        let remainingHydrationVolume = tracker.remainingHydrationVolume?.converted(to: .milliliters)

        #expect(totalHydrationVolume?.value == -75)
        #expect(remainingHydrationVolume?.value == 575)
    }

    // MARK: - Catalogue Snapshots

    // GIVEN coffees with distinct catalogue IDs and captured contributions, when
    // a breakdown is created, then IDs stay separate and stored estimates are summed.
    @Test func breakdownGroupsCatalogueIdentitiesAndPreservesEstimates() throws {
        let entries = [
            makeEntry(drinkID: "latte", name: "Latte", volume: 250, contribution: 200),
            makeEntry(drinkID: "latte", name: "Latte", volume: 100, contribution: -20),
            makeEntry(drinkID: "espresso", name: "Espresso", volume: 30, contribution: nil)
        ]
        let tracker = HydrationTracker(entries: entries, dailyGoal: goal)
        let breakdown = tracker.drinkBreakdown

        #expect(breakdown.map(\.drinkID) == ["espresso", "latte"])

        let espresso = try #require(breakdown.first)
        #expect(VolumeCalculation.baseValue(from: espresso.totalVolume) == 30)
        #expect(espresso.totalHydrationVolume == nil)

        let latte = try #require(breakdown.last)
        let hydration = try #require(latte.totalHydrationVolume)
        #expect(VolumeCalculation.baseValue(from: latte.totalVolume) == 350)
        #expect(VolumeCalculation.baseValue(from: hydration) == 180)
    }

    // GIVEN renamed entries with a tied latest timestamp, when their order changes,
    // then the breakdown keeps the latest name using UUID to resolve the tie.
    @Test func breakdownUsesLatestNameRegardlessOfEntryOrder() throws {
        let olderEntry = makeEntry(
            drinkID: "latte", name: "Old name", volume: 250, contribution: 200,
            loggedAt: 1000, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let latestEntry = makeEntry(
            drinkID: "latte", name: "Latest name", volume: 250, contribution: 200,
            loggedAt: 2000, id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        )
        let tiedEntry = makeEntry(
            drinkID: "latte", name: "Other name", volume: 250, contribution: 200,
            loggedAt: 2000, id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )

        for entries in [[olderEntry, latestEntry, tiedEntry], [tiedEntry, latestEntry, olderEntry]] {
            let tracker = HydrationTracker(entries: entries, dailyGoal: goal)
            let breakdown = try #require(tracker.drinkBreakdown.first)

            #expect(breakdown.drinkID == "latte")
            #expect(breakdown.displayName == "Latest name")
        }
    }

    private var goal: HydrationGoal {
        HydrationGoal(amount: DrinkAmount(value: 2000, unit: .milliliters))
    }

    private func makeEntry(
        drinkID: String,
        name: String,
        volume: Double,
        contribution: Double?,
        loggedAt: TimeInterval = 1000,
        id: UUID = UUID()
    ) -> DrinkEntry {
        let snapshot = DrinkCatalogueSnapshot(
            drinkID: drinkID,
            drinkName: name,
            caffeineVariant: .regular,
            shotCount: nil,
            hydrationContribution: contribution,
            caffeineAmount: nil,
            catalogueVersion: "test-1",
            calculationVersion: "1",
            catalogueSchemaVersion: 1
        )

        return DrinkEntry(
            id: id,
            amount: DrinkAmount(value: volume, unit: .milliliters),
            date: Date(timeIntervalSince1970: loggedAt),
            catalogueSnapshot: snapshot
        )
    }
}
