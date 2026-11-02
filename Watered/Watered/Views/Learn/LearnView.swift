//
//  LearnView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

// MARK: - Learn View

/// Presents saved drink history as calendar-day groups in the temporary Stats tab.
///
/// Volumes follow the app's display preference; persistence remains owned by the parent.
struct LearnView: View {
    let onOpenProfile: () -> Void

    /// The full saved history, rather than the entries filtered for Today.
    let entries: [DrinkEntry]

    /// The applied volume unit shared by history rows and their detail screens.
    let displayUnit: LiquidUnit

    /// Requests deletion by entry UUID; errors are presented by the detail screen.
    let onDeleteDrink: (UUID) throws -> Void

    /// Newest-first calendar-day groups, with each group's entries also newest first.
    private var entriesByCalendarDay: [(day: Date, entries: [DrinkEntry])] {
        let calendar = Calendar.current
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.loggedAt)
        }
        
        return groupedEntries
            .map { day, entries in
                (
                    day: day,
                    entries: entries.sorted { firstEntry, secondEntry in
                        firstEntry.loggedAt > secondEntry.loggedAt
                    }
                )
            }
            .sorted { firstSection, secondSection in
                firstSection.day > secondSection.day
            }
    }

    /// Formats a history row's volume using the current display preference.
    ///
    /// - Parameter entry: The saved entry whose original amount remains unchanged.
    /// - Returns: The converted volume with up to three decimal places.
    private func amountText(for entry: DrinkEntry) -> String {
        VolumeFormatter().string(from: entry.amount.volume, displayedAs: displayUnit)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Section("Persisted drink entries") {
                        Text("No persisted drinks yet")
                    }
                } else {
                    ForEach(entriesByCalendarDay, id: \.day) { section in
                        Section(section.day.formatted(date: .complete, time: .omitted)) {
                            ForEach(section.entries) { entry in
                                NavigationLink {
                                    StatsDrinkEntryDetailView(
                                        entry: entry,
                                        displayUnit: displayUnit,
                                        onDeleteDrink: onDeleteDrink
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(entry.displayName) · \(amountText(for: entry))")
                                            .font(.headline)
                                        Text(entry.loggedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityIdentifier("statsDrinkEntryLink")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Stats")
    }
}

#Preview {
    LearnView(
        onOpenProfile: {},
        entries: [],
        displayUnit: .milliliters,
        onDeleteDrink: { entryID in
            wateredLog("Preview deletion requested for \(entryID)")
        }
    )
}
