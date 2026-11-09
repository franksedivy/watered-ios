import Foundation
import SwiftData
import Testing
@testable import Watered

/// The old entity keeps its original name and fields, allowing a real on-disk upgrade check.
private enum PreAlcoholStore {
    @Model
    final class PersistentDrinkEntry {
    var id: UUID = UUID()
    var volumeValue: Double = 0
    var unitID: String = "milliliters"
    var loggedAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var source: String = "manual"

    /// The saved catalogue identity, independent of the current catalogue.
    var catalogueDrinkID: String? = nil

    /// The name captured when logging, retained for unavailable drinks.
    var catalogueDrinkName: String? = nil

    /// The selected caffeine preparation's raw value.
    var caffeineVariantID: String? = nil

    /// The selected shot count, or nil when shots do not apply.
    var shotCount: Int? = nil

    /// The captured hydration estimate in millilitres; nil means unknown.
    var hydrationContribution: Double? = nil

    /// The captured caffeine estimate in milligrams; nil means unknown, zero means known zero.
    var caffeineAmount: Double? = nil

    /// The catalogue content version used when logging.
    var catalogueVersion: String? = nil

    /// The calculation version used to produce the saved estimates.
    var calculationVersion: String? = nil

    /// The original JSON schema version, or nil for entries that did not capture it.
    var catalogueSchemaVersion: Int? = nil


        init() {}
    }
}

@MainActor
struct AlcoholStoreUpgradeTests {
    @Test func existingDiskStoreUpgradesWithoutRewritingSavedFacts() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("history.store")
        let id = UUID()
        try createOldStore(at: url, id: id)
        let container = try ModelContainer(for: PersistentDrinkEntry.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let rows = try ModelContext(container).fetch(FetchDescriptor<PersistentDrinkEntry>())
        let row = try #require(rows.first)
        #expect(rows.count == 1)
        let entry = try #require(row.drinkEntry())
        #expect(entry.id == id)
        #expect(entry.amount.value == 175)
        #expect(entry.displayName == "Original wine")
        #expect(entry.catalogueSnapshot.hydrationContribution == -52.5)
        #expect(entry.catalogueSnapshot.caffeineAmount == nil)
        #expect(entry.catalogueSnapshot.catalogueVersion == "before-alcohol")
        #expect(entry.catalogueSnapshot.calculationVersion == "1")
        #expect(entry.catalogueSnapshot.isNonAlcoholic == nil)
        #expect(entry.catalogueSnapshot.alcoholABV == nil)
        #expect(entry.catalogueSnapshot.alcoholABVUpperBound == nil)
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        let newEntry = try AddDrinkDraft(drinkID: "wine", volumeValue: 175, unit: .milliliters,
            isNonAlcoholic: true).drinkEntry(using: resolver)
        try DrinkEntryPersistence.save(newEntry, in: ModelContext(container))
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<PersistentDrinkEntry>()) == 2)
        #expect(row.drinkEntry()?.catalogueSnapshot.hydrationContribution == -52.5)
    }

    private func createOldStore(at url: URL, id: UUID) throws {
        let container = try ModelContainer(for: PreAlcoholStore.PersistentDrinkEntry.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let row = PreAlcoholStore.PersistentDrinkEntry()
        row.id = id
        row.volumeValue = 175
        row.catalogueDrinkID = "wine"
        row.catalogueDrinkName = "Original wine"
        row.caffeineVariantID = "regular"
        row.hydrationContribution = -52.5
        row.catalogueVersion = "before-alcohol"
        row.calculationVersion = "1"
        row.catalogueSchemaVersion = 1
        context.insert(row)
        try context.save()
    }
}
