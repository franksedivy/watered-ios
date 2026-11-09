import Foundation
import Testing
@testable import Watered

@MainActor
struct ReviewedCoffeeEstimateTests {
    @Test func defaultsResolvePerDrink() throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        for (id, shots) in [("espresso", 1), ("cappuccino", 1), ("latte", 2), ("americano", 2), ("iced-coffee", 2)] {
            let snapshot = try resolver.resolve(drinkID: id, amount: DrinkAmount(value: 250, unit: .milliliters))
            #expect(snapshot.shotCount == shots)
            #expect(snapshot.caffeineAmount == Double(shots * 60))
        }
    }

    @Test(arguments: LiquidUnit.allCases)
    func estimatesUsePhysicalVolumeAndShots(unit: LiquidUnit) throws {
        let resolver = try DrinkCatalogueSnapshotResolver(catalogue: DrinkCatalogueLoader().load())
        for volume in [250.0, 400.0, 500.0] {
            let converted = Measurement(value: volume, unit: UnitVolume.milliliters).converted(to: unit.foundationUnit)
            let amount = DrinkAmount(value: converted.value, unit: unit)
            for variant in [CaffeineVariant.regular, .decaf] {
                let regular = variant == .regular
                for (id, concentration) in [("coffee-with-milk", regular ? 40.0 : 2.0), ("cold-brew", regular ? 50.0 : 5.0)] {
                    let snapshot = try resolver.resolve(drinkID: id, amount: amount, caffeineVariant: variant)
                    #expect(abs(try #require(snapshot.caffeineAmount) - volume / 100 * concentration) < 0.000001)
                }
                for shots in 0...4 {
                    let snapshot = try resolver.resolve(drinkID: "latte", amount: amount, caffeineVariant: variant, shotCount: shots)
                    #expect(snapshot.caffeineAmount == Double(shots) * (regular ? 60 : 5))
                    #expect(abs(try #require(snapshot.hydrationContribution) - volume * 0.906) < 0.000001)
                }
            }
        }
    }

    @Test func oldUnknownSnapshotSurvivesPersistenceAndRepeat() throws {
        let snapshot = DrinkCatalogueSnapshot(
            drinkID: "latte", drinkName: "Latte", caffeineVariant: .decaf, shotCount: 3,
            hydrationContribution: 226.5, caffeineAmount: nil,
            catalogueVersion: "development-3", calculationVersion: "2", catalogueSchemaVersion: 2
        )
        let entry = DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
                               date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
        let record = PersistentDrinkEntry(drinkEntry: entry)
        let restored = try #require(record.drinkEntry())
        let catalogue = try DrinkCatalogueLoader().load()
        let store = WateredStore(entries: [restored])
        let recent = try #require(store.recentDrinkOptions(in: catalogue).first)
        let repeated = try recent.drinkEntry(using: DrinkCatalogueSnapshotResolver(catalogue: catalogue))
        #expect(repeated.id != restored.id)
        #expect(repeated.catalogueSnapshot.caffeineAmount == 15)
        #expect(repeated.catalogueSnapshot.catalogueVersion == "development-8")
        #expect(repeated.catalogueSnapshot.hydrationContribution == 226.5)
        #expect(record.drinkEntry()?.catalogueSnapshot == snapshot)
        #expect(store.entries.first?.catalogueSnapshot == snapshot)
    }

    @Test func oldIcedCoffeeWithoutShotsRemainsReadableButUnavailableInRecents() throws {
        let snapshot = DrinkCatalogueSnapshot(
            drinkID: "iced-coffee", drinkName: "Iced coffee", caffeineVariant: .regular, shotCount: nil,
            hydrationContribution: 247.5, caffeineAmount: nil,
            catalogueVersion: "development-3", calculationVersion: "2", catalogueSchemaVersion: 2
        )
        let entry = DrinkEntry(amount: DrinkAmount(value: 250, unit: .milliliters),
                               date: Date(timeIntervalSince1970: 1000), catalogueSnapshot: snapshot)
        let restored = try #require(PersistentDrinkEntry(drinkEntry: entry).drinkEntry())
        let store = WateredStore(entries: [restored])
        #expect(store.recentDrinkOptions(in: try DrinkCatalogueLoader().load()).isEmpty)
        #expect(store.entries.first?.catalogueSnapshot == snapshot)
    }

    @Test func contributionDisplayRoundsDownWithoutChangingProgressFormatting() {
        let formatter = ProgressFormatter()
        let locale = Locale(identifier: "en_US")
        for (ratio, expected) in [(0.906, "90.6%"), (0.981, "98.1%"), (0.994, "99.4%"), (0.90699, "90.6%"), (1.0, "100%"), (0.0, "0%"), (-0.3019, "-30.2%")] {
            #expect(formatter.contributionPercentageString(from: ratio, locale: locale) == expected)
        }
        #expect(formatter.contributionPercentageString(from: 0.90699, locale: Locale(identifier: "de_DE")).contains("90,6"))
        #expect(formatter.percentageString(from: 0.906) == "91%")
    }
}
