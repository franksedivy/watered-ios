import Foundation
import Testing
@testable import Watered

@MainActor
struct RecentDrinkOptionTests {
    // GIVEN history logged under older rules, when its shortcut is repeated under new rules,
    // THEN only the new entry adopts the new estimates and catalogue version.
    @Test func repeatingRecentDrinkResolvesCurrentRulesWithoutChangingHistory() throws {
        let oldCatalogue = makeCatalogue(version: "old", ratio: 1, caffeinePerShot: 60)
        let oldResolver = try DrinkCatalogueSnapshotResolver(catalogue: oldCatalogue)
        let oldEntry = try AddDrinkDraft(
            drinkID: "test-coffee", volumeValue: 250, unit: .milliliters
        ).drinkEntry(using: oldResolver, date: Date(timeIntervalSince1970: 1000))
        let store = WateredStore(entries: [oldEntry])
        let newCatalogue = makeCatalogue(version: "new", ratio: 0.5, caffeinePerShot: 80)
        let newResolver = try DrinkCatalogueSnapshotResolver(catalogue: newCatalogue)
        let shortcut = try #require(store.recentDrinkOptions(in: newCatalogue).first)

        let repeated = try shortcut.drinkEntry(
            using: newResolver, date: Date(timeIntervalSince1970: 2000)
        )

        #expect(repeated.id != oldEntry.id)
        #expect(repeated.loggedAt == Date(timeIntervalSince1970: 2000))
        #expect(repeated.catalogueSnapshot.hydrationContribution == 125)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 80)
        #expect(repeated.catalogueSnapshot.catalogueVersion == "new")
        #expect(oldEntry.catalogueSnapshot.hydrationContribution == 250)
        #expect(oldEntry.catalogueSnapshot.caffeineAmount == 60)
        #expect(oldEntry.catalogueSnapshot.catalogueVersion == "old")
        #expect(store.entries.count == 1)
        let tracker = HydrationTracker(
            entries: store.entries,
            dailyGoal: HydrationGoal(amount: DrinkAmount(value: 2000, unit: .milliliters))
        )
        #expect(tracker.totalHydrationVolume?.value == 250)
    }

    // GIVEN repeated amounts and different preparations, when shortcuts are built,
    // THEN caffeine variants, shot counts and original units remain distinct.
    @Test func recentsDeduplicateOnlyMatchingAmountsUnitsAndPreparations() throws {
        let catalogue = makeCatalogue()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let drafts = [
            AddDrinkDraft(drinkID: "test-coffee", volumeValue: 250, unit: .milliliters,
                          caffeineVariant: .regular, shotCount: 1),
            AddDrinkDraft(drinkID: "test-coffee", volumeValue: 250, unit: .milliliters,
                          caffeineVariant: .decaf, shotCount: 1),
            AddDrinkDraft(drinkID: "test-coffee", volumeValue: 250, unit: .milliliters,
                          caffeineVariant: .regular, shotCount: 2),
            AddDrinkDraft(drinkID: "test-coffee", volumeValue: 8, unit: .imperialFluidOunces,
                          caffeineVariant: .regular, shotCount: 1),
            AddDrinkDraft(drinkID: "test-coffee", volumeValue: 250, unit: .milliliters,
                          caffeineVariant: .regular, shotCount: 1)
        ]
        let entries = try drafts.enumerated().map { index, draft in
            try draft.drinkEntry(using: resolver, date: Date(timeIntervalSince1970: Double(index)))
        }
        let options = WateredStore(entries: entries).recentDrinkOptions(in: catalogue)

        #expect(options.count == 4)
        #expect(Set(options.map(\.id)).count == 4)
        #expect(options.first?.caffeineVariant == .regular)
        #expect(options.first?.shotCount == 1)
        #expect(options.contains { $0.caffeineVariant == .decaf })
        #expect(options.contains { $0.shotCount == 2 })
        #expect(options.contains { $0.amount.value == 8 && $0.amount.unit == .imperialFluidOunces })
    }

    // GIVEN a logged preparation that is no longer available, when Recents is requested,
    // THEN it is excluded from new submission while saved history remains readable.
    @Test(arguments: ["missing", "retired", "variant", "shots"])
    func recentsExcludeUnavailableSelectionsWithoutRemovingHistory(change: String) throws {
        let original = makeCatalogue()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: original)
        let entry = try AddDrinkDraft(
            drinkID: "test-coffee", volumeValue: 250, unit: .milliliters,
            caffeineVariant: .decaf, shotCount: 2
        ).drinkEntry(using: resolver)
        let updated = makeCatalogue(
            isRetired: change == "retired",
            includesDrink: change != "missing",
            includesDecaf: change != "variant",
            shotCounts: change == "shots" ? [1] : [1, 2]
        )
        try updated.validate()
        let store = WateredStore(entries: [entry])

        #expect(store.recentDrinkOptions(in: updated).isEmpty)
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.id == entry.id)
        #expect(store.entries.first?.displayName == "Test Coffee")
        #expect(store.entries.first?.catalogueSnapshot == entry.catalogueSnapshot)
    }

    // GIVEN two available drinks with identical display labels, when shortcuts are built,
    // THEN each catalogue identity remains individually selectable.
    @Test func equalLabelsDoNotCollapseDifferentDrinkIdentities() throws {
        let drinks = ["first-coffee", "second-coffee"].map { id in
            DrinkDefinition(id: id, name: "Same name", categoryID: "coffee",
                            sortOrder: 1, isRetired: false, hydrationContributionRule: .ratio(1))
        }
        let catalogue = DrinkCatalogue(
            schemaVersion: 1, version: "test-1",
            categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 1)],
            drinks: drinks
        )
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        let entries = try drinks.map { drink in
            try AddDrinkDraft(drinkID: drink.id, volumeValue: 250, unit: .milliliters)
                .drinkEntry(using: resolver)
        }
        let options = WateredStore(entries: entries).recentDrinkOptions(in: catalogue)

        #expect(options.count == 2)
        #expect(Set(options.map(\.id)).count == 2)
        #expect(Set(options.map(\.label)).count == 1)
    }

    private func makeCatalogue(
        version: String = "test-1",
        ratio: Double = 1,
        caffeinePerShot: Double = 60,
        isRetired: Bool = false,
        includesDrink: Bool = true,
        includesDecaf: Bool = true,
        shotCounts: [Int] = [1, 2]
    ) -> DrinkCatalogue {
        var options = [CaffeineOption(variant: .regular, rule: .perShot(amount: caffeinePerShot))]
        if includesDecaf {
            options.append(CaffeineOption(variant: .decaf, rule: .perShot(amount: 5)))
        }
        let drink = DrinkDefinition(
            id: "test-coffee", name: "Test Coffee", categoryID: "coffee", sortOrder: 1,
            isRetired: isRetired, hydrationContributionRule: .ratio(ratio),
            caffeineOptions: options, defaultCaffeineVariant: .regular,
            shotConfiguration: ShotConfiguration(supportedCounts: shotCounts, defaultCount: 1)
        )
        return DrinkCatalogue(
            schemaVersion: 1, version: version,
            categories: [DrinkCategory(id: "coffee", name: "Coffee", sortOrder: 1)],
            drinks: includesDrink ? [drink] : []
        )
    }
}
