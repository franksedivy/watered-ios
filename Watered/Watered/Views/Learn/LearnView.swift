//
//  LearnView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

// MARK: - Learn View
//
// Purpose:
// Shows the temporary Learn screen.
//
// Returns:
// A blank SwiftUI screen inside its own navigation stack.
//
// UI role:
// Gives Watered a second real tab so the app can start behaving like a
// multi-section iOS app. The content is intentionally empty for now because
// learning content is outside the current 0.2 UI foundation work.
struct LearnView: View {
    let onOpenProfile: () -> Void
    
    // Purpose:
    // Stores the drink entries shown by the temporary Stats tab
    //
    // Input:
    // Supplied by WateredTabView from the full app store, not the filtered Today
    // entries.
    //
    // UI role:
    // Lets the placeholder tab act as a simple history/debug view while persistence
    // and day filtering are being built.
    let entries: [DrinkEntry]
    
    // Purpose:
    // Requests deletion of a drink without owning persistence logic.
    //
    // Input:
    // Supplied by the parent' accepts the selected drink's UUID.
    //
    // Behavior:
    // Throws if saving fails so the detail screen can present an error.
    let onDeleteDrink: (UUID) throws -> Void
    
    // Purpose:
    // Groups the full drink  history by local calendar day for the temporary Stats
    //
    // Returns:
    // Date sections sorted newest-first, with each section containing entries from
    // the same local calendar day.
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
                                        onDeleteDrink: onDeleteDrink
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(entry.displayName) · \(entry.amount.formatted)")
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
        onDeleteDrink: { entryID in
            wateredLog("Preview deletion requested for \(entryID)")
        }
    )
}
