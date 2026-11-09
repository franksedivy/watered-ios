//
//  WateredStore.swift
//  Watered
//
//  Created by Frank Sedivy on 05/09/2026.
//

import Foundation
import Observation

/// Owns logged drink history shared by the app's views.
@Observable
final class WateredStore {
    /// The complete loaded history, including drinks absent from the current catalogue.
    private(set) var entries: [DrinkEntry]

    /// Creates app state from loaded entries or an empty history.
    init(entries: [DrinkEntry] = []) {
        self.entries = entries
    }

    /// Replaces app state with entries restored from persistence.
    ///
    /// - Parameter loadedEntries: Saved entries whose captured facts have been restored.
    func loadDrinkEntries(_ loadedEntries: [DrinkEntry]) {
        entries = loadedEntries
        wateredLog("Loaded \(entries.count) persisted drink entries into WateredStore")
    }

    /// Selects entries for one local calendar day without removing history.
    ///
    /// - Parameters:
    ///   - calendarDay: A date within the requested day.
    ///   - calendar: The calendar and time zone used to interpret that day.
    /// - Returns: Entries logged on the requested day.
    func drinkEntries(for calendarDay: Date, calendar: Calendar = .current) -> [DrinkEntry] {
        return entries.filter { entry in
            calendar.isDate(entry.loggedAt, inSameDayAs: calendarDay)
        }
    }

    /// Builds available shortcuts in newest-first order with UUID resolving tied times.
    ///
    /// Missing or retired drinks and unsupported preparations are excluded. Identity,
    /// amount, unit, caffeine variant, shot count, alcohol preparation and ABV distinguish shortcuts.
    ///
    /// - Parameter catalogue: The validated catalogue available for new submissions.
    /// - Returns: Distinct shortcuts that can be repeated using current rules.
    func recentDrinkOptions(in catalogue: DrinkCatalogue) -> [RecentDrinkOption] {
        let newestEntries = entries.sorted { first, second in
            if first.loggedAt == second.loggedAt {
                return first.id.uuidString > second.id.uuidString
            }
            return first.loggedAt > second.loggedAt
        }

        var options: [RecentDrinkOption] = []
        var includedIDs = Set<RecentDrinkOption.ID>()

        for entry in newestEntries {
            let snapshot = entry.catalogueSnapshot
            guard let definition = catalogue.drink(withID: entry.drinkID),
                  !definition.isRetired,
                  definition.caffeineOptions.contains(where: { option in
                      return option.variant == snapshot.caffeineVariant
                  })
            else {
                continue
            }

            if let configuration = definition.shotConfiguration {
                guard let count = snapshot.shotCount,
                      configuration.supportedCounts.contains(count)
                else {
                    continue
                }
            } else if snapshot.shotCount != nil {
                continue
            }

            if let configuration = definition.alcohol.configuration {
                if snapshot.isNonAlcoholic == true {
                    guard configuration.nonAlcoholic != nil else { continue }
                } else if let abv = snapshot.alcoholABV, !configuration.supportedABVs.contains(abv) {
                    continue
                }
            } else if snapshot.isNonAlcoholic == true {
                continue
            }

            let repeatABV = definition.alcohol.configuration.map { snapshot.alcoholABV ?? $0.defaultABV }
            let option = RecentDrinkOption(
                definition: definition,
                amount: entry.amount,
                caffeineVariant: snapshot.caffeineVariant,
                shotCount: snapshot.shotCount,
                isNonAlcoholic: snapshot.isNonAlcoholic ?? false,
                alcoholABV: snapshot.isNonAlcoholic == true ? nil : repeatABV
            )
            if includedIDs.insert(option.id).inserted {
                options.append(option)
            }
        }
        return options
    }

    /// Adds an entry after persistence succeeds and logs the accepted drink.
    ///
    /// - Parameter entry: The successfully saved submission.
    func addDrinkEntry(_ entry: DrinkEntry) {
        entries.append(entry)
        wateredLog(
            "Drink entry accepted by WateredStore: \(entry.displayName) \(entry.amount.formatted); "
            + "drink count is \(entries.count)"
        )
    }
}
