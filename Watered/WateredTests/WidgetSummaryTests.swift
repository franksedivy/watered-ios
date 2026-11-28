import Foundation
import SwiftData
import Testing
@testable import Watered

@MainActor
struct WidgetSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_795_867_200)

    private func calendar(_ zone: String = "Europe/Madrid", identifier: Calendar.Identifier = .gregorian) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func settings(_ unit: LiquidUnit = .milliliters, goal: Double = 2000,
                          goalUnit: LiquidUnit = .milliliters) -> AppSettings {
        AppSettings(displayUnit: unit, dailyHydrationGoal: HydrationGoal(amount: DrinkAmount(value: goal, unit: goalUnit)))
    }

    private func entry(_ contribution: Double?, date: Date? = nil) -> DrinkEntry {
        DrinkEntryFixture.make(drinkID: "retired-fixture", drinkName: "Captured name",
                               hydrationRule: .unknown, capturedHydrationContribution: contribution,
                               amount: DrinkAmount(value: 500, unit: .milliliters), date: date ?? now)
    }

    private func summary(_ entries: [DrinkEntry] = [], settings: AppSettings? = nil,
                         date: Date? = nil, calendar: Calendar? = nil) throws -> WidgetSummary {
        let result = WidgetSummaryDerivation.derive(committedEntries: entries,
                                                    appliedSettings: settings ?? self.settings(),
                                                    at: date ?? now, calendar: calendar ?? self.calendar())
        guard case .available(let summary) = result else {
            Issue.record("Expected available summary")
            throw WidgetSummaryCodec.EncodingFailure.invalidSummary
        }
        return summary
    }

    @Test func appParityAndRoundTrips() throws {
        let cases: [[Double?]] = [[], [250, 400], [250, nil], [-200], [0], [2000], [2300]]
        for contributions in cases {
            let entries = contributions.map { entry($0) }
            let value = try summary(entries)
            let app = HydrationTracker(entries: entries, dailyGoal: settings().dailyHydrationGoal).snapshot
            #expect(value.hydrationMillilitres == app.totalHydrationVolume?.value)
            #expect(value.remainingMillilitres == app.remainingHydrationVolume?.value)
            #expect(value.progressFraction == app.hydrationProgress)
            let data = try WidgetSummaryCodec.encode(value, at: now, calendar: calendar())
            #expect(WidgetSummaryCodec.decode(data, at: now, calendar: calendar()) == .available(value))
        }
        let negative = try summary([entry(-200)])
        #expect(negative.remainingMillilitres == 2200)
        #expect(negative.progressFraction == -0.1)
        #expect(try summary([entry(2300)]).progressFraction == 1.15)
        #expect(try summary().remainingMillilitres == 2000)
    }

    @Test func minimalPayloadAndExplicitUnknownKeys() throws {
        let value = try summary([entry(nil)])
        let data = try WidgetSummaryCodec.encode(value, at: now, calendar: calendar())
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == Set(["schemaVersion", "generatedAt", "dayStart", "dayEnd",
                                      "calendarIdentifier", "timeZoneIdentifier", "displayUnit", "goalMillilitres",
                                      "hydrationMillilitres", "remainingMillilitres", "progressFraction"]))
        for key in ["hydrationMillilitres", "remainingMillilitres", "progressFraction"] {
            #expect(object[key] is NSNull)
        }
        #expect(data.count < 1024)
    }

    @Test func allUnitPairsKeepCanonicalValues() throws {
        for displayUnit in LiquidUnit.allCases {
            for goalUnit in LiquidUnit.allCases {
                let applied = settings(displayUnit, goal: 80, goalUnit: goalUnit)
                let value = try summary([entry(300)], settings: applied)
                #expect(value.displayUnit == displayUnit.persistenceIdentifier)
                #expect(value.goalMillilitres == VolumeCalculation.baseValue(from: applied.dailyHydrationGoal.volume))
                #expect(value.hydrationMillilitres == 300)
                #expect(WidgetSummaryCodec.decode(try WidgetSummaryCodec.encode(value, at: now, calendar: calendar()),
                                                  at: now, calendar: calendar()) == .available(value))
            }
        }
    }

    @Test func committedSettingsReadDoesNotCreateHistory() throws {
        let container = try ModelContainer(for: PersistentAppSettings.self, PersistentHydrationGoalChange.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let record = try AppSettingsPersistence.loadOrCreate(defaults: settings(), in: context, at: now)
        _ = try AppSettingsPersistence.saveGoal(settings(goal: 2500).dailyHydrationGoal, source: .manual,
                                                settings: record, in: context, at: now)
        for unit in LiquidUnit.allCases {
            _ = try AppSettingsPersistence.saveDisplayUnit(unit, settings: record, in: context, at: now)
            let reader = ModelContext(container)
            let saved = try #require(reader.fetch(FetchDescriptor<PersistentAppSettings>()).first?.appSettings())
            let value = try summary(settings: saved)
            #expect(value.goalMillilitres == 2500)
            #expect(value.displayUnit == unit.persistenceIdentifier)
            #expect(try reader.fetchCount(FetchDescriptor<PersistentHydrationGoalChange>()) == 2)
            #expect(!reader.hasChanges)
        }
    }

    @Test func capturedFactsDoNotConsultCurrentCatalogue() throws {
        // The identity has no current definition; a new calculation would give 500, not the captured -125.
        let saved = DrinkEntryFixture.make(drinkID: "removed-definition", drinkName: "Old name",
                                          hydrationRule: .ratio(1), capturedHydrationContribution: -125,
                                          amount: DrinkAmount(value: 500, unit: .milliliters), date: now)
        let value = try summary([saved])
        #expect(value.hydrationMillilitres == -125)
        #expect(saved.catalogueSnapshot.hydrationContribution == -125)
        #expect(saved.displayName == "Old name")
    }

    @Test func dayBoundariesAndDSTMatchStore() throws {
        let madrid = calendar()
        for (month, day, hours) in [(3, 29, 23), (10, 25, 25)] {
            let date = try #require(madrid.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
            let interval = try #require(madrid.dateInterval(of: .day, for: date))
            let entries = [entry(100, date: interval.start.addingTimeInterval(-1)),
                           entry(200, date: interval.start), entry(300, date: interval.end.addingTimeInterval(-1)),
                           entry(400, date: interval.end)]
            let value = try summary(entries, date: date, calendar: madrid)
            #expect(value.dayEnd - value.dayStart == Double(hours * 3600))
            #expect(value.hydrationMillilitres == 500)
            let appEntries = WateredStore(entries: entries).drinkEntries(for: date, calendar: madrid)
            #expect(appEntries.count == 2)
            #expect(HydrationTracker(entries: appEntries, dailyGoal: settings().dailyHydrationGoal).snapshot.hydrationProgress == value.progressFraction)
        }
    }

    @Test func currentDayCalendarZoneAndReadClockAreRequired() throws {
        let value = try summary()
        let data = try WidgetSummaryCodec.encode(value, at: now, calendar: calendar())
        #expect(WidgetSummaryCodec.decode(data, at: now.addingTimeInterval(-1), calendar: calendar()) == .unavailable)
        #expect(WidgetSummaryCodec.decode(data, at: Date(timeIntervalSince1970: value.dayEnd), calendar: calendar()) == .unavailable)
        #expect(WidgetSummaryCodec.decode(data, at: Date(timeIntervalSince1970: value.dayEnd - 1), calendar: calendar()) == .available(value))
        #expect(WidgetSummaryCodec.decode(data, at: now, calendar: calendar("UTC")) == .unavailable)
        #expect(WidgetSummaryCodec.decode(data, at: now, calendar: calendar(identifier: .buddhist)) == .unavailable)
        for zone in ["Pacific/Kiritimati", "America/Los_Angeles", "Asia/Kathmandu"] {
            let local = calendar(zone)
            let result = try summary(date: now, calendar: local)
            #expect(result.timeZoneIdentifier == zone)
            #expect(result.isValid(at: now, calendar: local))
        }
        let buddhist = calendar(identifier: .buddhist)
        #expect(try summary(calendar: buddhist).isValid(at: now, calendar: buddhist))
    }

    @Test func malformedMissingAndInconsistentPayloadsAreUnavailable() throws {
        let data = try WidgetSummaryCodec.encode(summary([entry(250)]), at: now, calendar: calendar())
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        func read(_ object: [String: Any]) throws -> WidgetSummaryReadResult {
            WidgetSummaryCodec.decode(try JSONSerialization.data(withJSONObject: object), at: now, calendar: calendar())
        }
        for key in original.keys {
            var missing = original
            missing.removeValue(forKey: key)
            #expect(try read(missing) == .unavailable)
            var wrongType = original
            wrongType[key] = ["unexpected"]
            #expect(try read(wrongType) == .unavailable)
        }
        let invalid: [(String, Any)] = [
            ("schemaVersion", 2), ("schemaVersion", 1.5), ("schemaVersion", true),
            ("calendarIdentifier", "invalid"), ("timeZoneIdentifier", "invalid"), ("displayUnit", "ml"),
            ("goalMillilitres", 0), ("goalMillilitres", -1), ("hydrationMillilitres", NSNull()),
            ("remainingMillilitres", -1), ("remainingMillilitres", 100), ("progressFraction", 0.5),
            ("generatedAt", now.timeIntervalSince1970 + 1), ("dayStart", now.timeIntervalSince1970),
            ("dayEnd", now.timeIntervalSince1970), ("history", [])
        ]
        for (key, replacement) in invalid {
            var object = original
            object[key] = replacement
            #expect(try read(object) == .unavailable, "Rejected field: \(key)")
        }
        #expect(WidgetSummaryCodec.decode(nil, at: now, calendar: calendar()) == .unavailable)
        #expect(WidgetSummaryCodec.decode(Data("{broken".utf8), at: now, calendar: calendar()) == .unavailable)
        #expect(WidgetSummaryCodec.decode(Data("[]".utf8), at: now, calendar: calendar()) == .unavailable)
        let padded = data + Data(repeating: 32, count: WidgetSummaryCodec.maximumPayloadBytes - data.count)
        #expect(WidgetSummaryCodec.decode(padded, at: now, calendar: calendar()) != .unavailable)
        #expect(WidgetSummaryCodec.decode(padded + Data([32]), at: now, calendar: calendar()) == .unavailable)
    }

    @Test func invalidNumbersAndArithmeticTolerance() throws {
        for invalidGoal in [0, -1, Double.infinity, Double.nan] {
            #expect(WidgetSummaryDerivation.derive(committedEntries: [], appliedSettings: settings(goal: invalidGoal),
                                                   at: now, calendar: calendar()) == .unavailable)
        }
        #expect(WidgetSummaryDerivation.derive(committedEntries: [entry(.infinity)], appliedSettings: settings(),
                                               at: now, calendar: calendar()) == .unavailable)
        let data = try WidgetSummaryCodec.encode(summary([entry(250)]), at: now, calendar: calendar())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["progressFraction"] = 0.125 + 1e-10
        #expect(WidgetSummaryCodec.decode(try JSONSerialization.data(withJSONObject: object), at: now, calendar: calendar()) != .unavailable)
        object["progressFraction"] = 0.125 + 1e-7
        #expect(WidgetSummaryCodec.decode(try JSONSerialization.data(withJSONObject: object), at: now, calendar: calendar()) == .unavailable)
    }
}
