//
//  TodayCalendarDay.swift
//  Watered
//
//  Created by Frank Sedivy on 06/09/2026.
//

import Foundation

// MARK: - Today Calendar Day
/// Stores the date and calendar used to select Today’s entries.
/// Callers refresh the date when the active day changes.
nonisolated struct TodayCalendarDay {
    private(set) var date: Date
    let calendar: Calendar
    
    init(
        date: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.date = date
        self.calendar = calendar
    }
    
    // MARK: - Refreshing
    /// Replaces the active date without changing the calendar or stored drink history.
    mutating func refresh(now: Date = Date()) {
        date = now
    }
    
    // MARK: - Entry Filtering
    /// Returns whether the entry’s logged time shares the active date’s calendar day.
    func contains(_ entry: DrinkEntry) -> Bool {
        return calendar.isDate(entry.loggedAt, inSameDayAs: date)
    }
}
