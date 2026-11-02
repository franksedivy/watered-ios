import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkEntryTests {
    // Given captured identity, amount, and date values, when a drink entry is created,
    // then the entry stores those values unchanged.
    @Test func drinkEntryStoresIdentityAmountAndDate() {
        let date = Date()
        let amount = DrinkAmount(value: 250, unit: .milliliters)

        let entry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: amount,
            date: date
        )

        #expect(entry.drinkID == "still-water")
        #expect(entry.amount.formatted == "250 ml")
        #expect(entry.date == date)
    }

    // Given a drink entry created without explicit persistence metadata,
    // when the entry is initialised, then it receives default metadata ready
    // for persistence.
    @Test func drinkEntryCreatesManualMetadataByDefault() {
        let loggedDate = Date()
        let entry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: loggedDate
        )

        #expect(entry.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(entry.loggedAt == loggedDate)
        #expect(entry.source == .manual)
        #expect(entry.createdAt <= Date())
        #expect(entry.updatedAt <= Date())
    }

    // Given two drink entries created without explicit identifiers, when their
    // IDs are compared, then each entry has a distinct identifier for persistence.
    @Test func drinkEntryCreatesDifferentIdentifiersByDefault() {
        let firstEntry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let secondEntry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        #expect(firstEntry.id != secondEntry.id)
    }

    // Given explicit metadata values from persistence, when a drink entry is
    // recreated, then the model preserves the metadata exactly.
    @Test func drinkEntryAcceptsExplicitPersistenceMetadata() {
        let id = UUID()
        let loggedDate = Date(timeIntervalSince1970: 1000)
        let createdAt = Date(timeIntervalSince1970: 2000)
        let updatedAt = Date(timeIntervalSince1970: 3000)

        let entry = DrinkEntryFixture.make(
            id: id,
            drinkID: "latte",
            drinkName: "Coffee",
            hydrationRule: .ratio(0.99),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: loggedDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: .manual,
        )

        #expect(entry.id == id)
        #expect(entry.date == loggedDate)
        #expect(entry.loggedAt == loggedDate)
        #expect(entry.createdAt == createdAt)
        #expect(entry.updatedAt == updatedAt)
        #expect(entry.source == .manual)
    }

    // Given a drink entry, when its description is read, then it includes the
    // captured drink name and formatted amount.
    @Test func drinkEntryDescriptionIncludesCapturedNameAndAmount() {
        let entry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        #expect(entry.description == "Water, 250 ml")
    }

    // Given an entry with a full-volume captured contribution, when it is read,
    // then the saved estimate equals the consumed amount.
    @Test func drinkEntryHydrationContributionVolumeKeepsFullWaterAmount() {
        let entry = DrinkEntryFixture.make(
            drinkID: "still-water",
            drinkName: "Water",
            hydrationRule: .ratio(1),
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == 250)
    }

    // Given an entry with a reduced captured contribution, when it is read,
    // then the original reduced estimate is preserved.
    @Test func drinkEntryReadsCapturedReducedContribution() {
        let entry = DrinkEntryFixture.make(
            drinkID: "test-juice",
            drinkName: "Juice",
            hydrationRule: .ratio(0.89),
            amount: DrinkAmount(value: 100, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == 89)
    }

    // Given an other drink entry, when its hydration contribution is requested,
    // then Watered returns nil because the contribution is unknown.
    @Test func drinkEntryOtherHydrationContributionVolumeIsUnknown() {
        let entry = DrinkEntryFixture.make(
            drinkID: "test-other",
            drinkName: "Other",
            hydrationRule: .unknown,
            amount: DrinkAmount(value: 250, unit: .milliliters),
            date: Date()
        )

        #expect(entry.hydrationContributionVolume == nil)
    }

    // Given a captured positive estimate below consumed volume, when it is read,
    // then that reduced contribution remains unchanged.
    @Test func drinkEntryBeerHydrationContributionIsPositiveButReduced() {
        let entry = DrinkEntryFixture.make(
            drinkID: "test-beer",
            drinkName: "Beer",
            hydrationRule: .alcohol(defaultABV: 0.05),
            amount: DrinkAmount(value: 330, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == 165)
    }

    // Given a captured negative estimate, when it is read,
    // then the negative contribution remains unchanged.
    @Test func drinkEntrySpiritsHydrationContributionIsNegative() {
        let entry = DrinkEntryFixture.make(
            drinkID: "test-spirits",
            drinkName: "Spirits",
            hydrationRule: .alcohol(defaultABV: 0.40),
            amount: DrinkAmount(value: 25, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == -75)
    }

    // Given another captured negative estimate, when it is read,
    // then the saved value remains unchanged.
    @Test func drinkEntryWineHydrationContributionIsNegative() {
        let entry = DrinkEntryFixture.make(
            drinkID: "test-wine",
            drinkName: "Wine",
            hydrationRule: .alcohol(defaultABV: 0.13),
            amount: DrinkAmount(value: 150, unit: .milliliters),
            date: Date()
        )

        let hydrationContributionVolume = entry.hydrationContributionVolume?.converted(to: .milliliters)

        #expect(hydrationContributionVolume?.value == -45)
    }

}
