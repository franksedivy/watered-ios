import Foundation
import SwiftData
import Testing
@testable import Watered

/// Each disk operation owns and releases its container; only value types cross reopen boundaries.
@MainActor
struct CatalogueDiskIntegrationTests {
    @Test(arguments: LiquidUnit.allCases)
    func completeBundleSurvivesDiskReopenAndCurrentRuleRepeats(unit: LiquidUnit) throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        #expect(catalogue.drinks.count == 60)
        #expect(catalogue.categories.count == 10)
        let amount = Measurement(value: 250.0, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
        let entries = try catalogue.drinks.enumerated().map { index, definition in
            try AddDrinkDraft(drinkID: definition.id, volumeValue: amount.value, unit: unit)
                .drinkEntry(using: resolver, date: Date(timeIntervalSince1970: Double(index)))
        }
        try withTemporaryStore { url in
            try save(entries, at: url)
            #expect(FileManager.default.fileExists(atPath: url.path))
            let restored = try read(at: url)
            assertSameEntries(restored, entries)
            let options = WateredStore(entries: restored).recentDrinkOptions(in: catalogue)
            #expect(options.count == 60)
            let repeats = try options.map { try $0.drinkEntry(using: resolver, date: Date(timeIntervalSince1970: 2000)) }
            for repeated in repeats {
                let original = try #require(entries.first { $0.drinkID == repeated.drinkID })
                #expect(repeated.id != original.id)
                #expect(repeated.loggedAt != original.loggedAt)
                #expect(repeated.amount.value == original.amount.value)
                #expect(repeated.amount.unit == unit)
                #expect(repeated.catalogueSnapshot == original.catalogueSnapshot)
                #expect(repeated.catalogueSnapshot.calculationVersion == "4")
            }
            try save(repeats, at: url)
            assertSameEntries(try read(at: url), entries + repeats)
        }
    }

    @Test(arguments: ["changed", "removed", "retired", "preparation"])
    func catalogueChangesPreserveDiskHistoryAndValidateBothSubmissionPaths(change: String) throws {
        let original = try DrinkCatalogueLoader().load()
        let draft = AddDrinkDraft(drinkID: "latte", volumeValue: 500, unit: .milliliters,
                                  caffeineVariant: .decaf, shotCount: 3)
        let entry = try draft.drinkEntry(using: DrinkCatalogueSnapshotResolver(catalogue: original),
                                        date: Date(timeIntervalSince1970: 1000))
        let staleShortcut = try #require(WateredStore(entries: [entry]).recentDrinkOptions(in: original).first)
        let updated = try changedCatalogue(original, change: change)
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: updated)
        try withTemporaryStore { url in
            try save([entry], at: url)
            let restored = try read(at: url)
            assertSameEntries(restored, [entry])
            let store = WateredStore(entries: restored)
            let options = store.recentDrinkOptions(in: updated)
            if change == "changed" {
                let option = try #require(options.first)
                let repeated = try option.drinkEntry(using: resolver, date: Date(timeIntervalSince1970: 2000))
                #expect(repeated.id != entry.id)
                #expect(repeated.amount.value == 500)
                #expect(repeated.catalogueSnapshot.drinkName == "Updated latte")
                #expect(repeated.catalogueSnapshot.caffeineVariant == .decaf)
                #expect(repeated.catalogueSnapshot.shotCount == 3)
                #expect(repeated.catalogueSnapshot.hydrationContribution == 250)
                #expect(repeated.catalogueSnapshot.catalogueVersion == "integration-update")
                try save([repeated], at: url)
                assertSameEntries(try read(at: url), [entry, repeated])
            } else {
                #expect(options.isEmpty)
                #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                    _ = try draft.drinkEntry(using: resolver)
                }
                #expect(throws: DrinkCatalogueSnapshotResolver.ResolutionError.self) {
                    _ = try staleShortcut.drinkEntry(using: resolver)
                }
                if change != "preparation" {
                    #expect(!updated.activeDrinks(inCategoryID: "coffee").contains { $0.id == "latte" })
                }
            }
            assertSameEntries(try read(at: url).filter { $0.id == entry.id }, [entry])
            try delete(entry.id, at: url)
            #expect(try read(at: url).allSatisfy { $0.id != entry.id })
            #expect(try read(at: url).count == (change == "changed" ? 1 : 0))
        }
    }

    @Test func unavailableCataloguePreservesUnknownZeroNegativeAndAlcoholFactsOnDisk() throws {
        let catalogue = try DrinkCatalogueLoader().load()
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: catalogue)
        var entries = try [false, true].map { nonAlcoholic in
            try AddDrinkDraft(drinkID: "beer", volumeValue: 330, unit: .milliliters,
                              isNonAlcoholic: nonAlcoholic).drinkEntry(using: resolver,
                              date: Date(timeIntervalSince1970: 1000))
        }
        for contribution in [Optional<Double>.none, 0, -75] {
            let snapshot = DrinkCatalogueSnapshot(drinkID: "removed-drink", drinkName: "Captured name",
                caffeineVariant: .regular, shotCount: nil, hydrationContribution: contribution,
                caffeineAmount: contribution == nil ? nil : 0, catalogueVersion: "historical",
                calculationVersion: "1", catalogueSchemaVersion: 1)
            entries.append(DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
                date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot))
        }
        try withTemporaryStore { url in
            try save(entries, at: url)
            #expect(throws: DecodingError.self) {
                _ = try DrinkCatalogueLoader().load(from: Data("broken".utf8), categoryData: { _ in Data() })
            }
            let restored = try read(at: url)
            assertSameEntries(restored, entries)
            let beer = try #require(restored.first { $0.catalogueSnapshot.isNonAlcoholic == false })
            let nonAlcoholic = try #require(restored.first { $0.catalogueSnapshot.isNonAlcoholic == true })
            #expect(beer.catalogueSnapshot.alcoholABV == 0.05)
            #expect(beer.catalogueSnapshot.hydrationContribution == 0)
            #expect(nonAlcoholic.catalogueSnapshot.alcoholABV == nil)
            #expect(nonAlcoholic.catalogueSnapshot.alcoholABVUpperBound == 0.005)
            #expect(nonAlcoholic.catalogueSnapshot.hydrationContribution == 313.5)
            let tracker = HydrationTracker(entries: restored,
                dailyGoal: HydrationGoal(amount: DrinkAmount(value: 2000, unit: .milliliters)))
            #expect(tracker.totalVolume.value == 1410)
            #expect(tracker.totalHydrationVolume == nil)
            #expect(Set(tracker.drinkBreakdown.map(\.drinkID)) == ["beer", "removed-drink"])
            for entry in entries { try delete(entry.id, at: url) }
            #expect(try read(at: url).isEmpty)
        }
    }

    private func changedCatalogue(_ catalogue: DrinkCatalogue, change: String) throws -> DrinkCatalogue {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(catalogue)) as? [String: Any])
        var drinks = try #require(json["drinks"] as? [[String: Any]])
        let index = try #require(drinks.firstIndex { $0["id"] as? String == "latte" })
        switch change {
        case "removed": drinks.remove(at: index)
        case "retired": drinks[index]["isRetired"] = true
        case "preparation": drinks[index]["caffeine"] = ["kind": "options", "defaultVariant": "regular",
            "options": [["variant": "regular", "rule": ["kind": "perShot", "amount": 60]]]]
        default:
            drinks[index]["name"] = "Updated latte"
            drinks[index]["hydrationContributionRule"] = ["kind": "ratio", "ratio": 0.5]
        }
        json["drinks"] = drinks
        json["version"] = "integration-update"
        let updated = try JSONDecoder().decode(DrinkCatalogue.self, from: JSONSerialization.data(withJSONObject: json))
        try updated.validate()
        return updated
    }

    private func withTemporaryStore(_ body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder.appendingPathComponent("history.store"))
    }

    private func container(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
    }

    private func save(_ entries: [DrinkEntry], at url: URL) throws {
        let container = try container(at: url)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        for entry in entries { try DrinkEntryPersistence.save(entry, in: context) }
    }

    private func read(at url: URL) throws -> [DrinkEntry] {
        let container = try container(at: url)
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<PersistentDrinkEntry>()).map { try #require($0.drinkEntry()) }
    }

    private func delete(_ id: UUID, at url: URL) throws {
        let container = try container(at: url)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<PersistentDrinkEntry>()).filter { $0.id == id }
        #expect(try DrinkEntryPersistence.delete(rows, in: context) == [id])
    }

    private func assertSameEntries(_ actual: [DrinkEntry], _ expected: [DrinkEntry]) {
        #expect(actual.count == expected.count)
        for entry in expected {
            let restored = actual.first { $0.id == entry.id }
            #expect(restored?.catalogueSnapshot == entry.catalogueSnapshot)
            #expect(restored?.amount.value == entry.amount.value)
            #expect(restored?.amount.unit == entry.amount.unit)
            #expect(restored?.loggedAt == entry.loggedAt)
            #expect(restored?.createdAt == entry.createdAt)
            #expect(restored?.updatedAt == entry.updatedAt)
            #expect(restored?.source == entry.source)
        }
    }
}
