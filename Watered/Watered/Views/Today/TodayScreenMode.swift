//
//  TodayScreenMode.swift
//  Watered
//
//  Created by Frank Sedivy on 26/08/2026.
//
// MARK: - Today Screen Mode
/// Names Today’s presentation states; TodayView selects a state from entries and progress.
enum TodayScreenMode {
    case empty          // Empty screen when no drinks have been logged
    case firstDrink     // First drink has been logged, mostly used to celebrate engagement
    case inProgress     // Most common use when drinks are logged during the day
    case goalReached    // Used for when the user's hydration goal has been reached
}

