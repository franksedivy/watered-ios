//
//  TodayAppearance.swift
//  Watered
//
//  Created by Frank Sedivy on 29/08/2026.
//

import SwiftUI

// MARK: - Today Appearance
/// Provides Today’s screen spacing and mode-specific backgrounds independently of hydration calculations.
struct TodayAppearance {
    let screenHorizontalPadding: CGFloat = 16
    
    /// Uses the empty-state background only for empty mode; all logged-drink modes share the active background.
    func backgroundGradient(for mode: TodayScreenMode) -> LinearGradient {
        switch mode {
        case .empty:
            return emptyBackgroundGradient
        
        case .firstDrink, .inProgress, .goalReached:
            return activeBackgroundGradient
        }
    }
    
    private let activeBackgroundGradient = LinearGradient(
        colors: [
            Color(red: 128.0 / 255.0, green: 195.0 / 255.0, blue: 243.0 / 255.0),
            Color(red: 74.0 / 255.0, green: 144.0 / 255.0, blue: 226.0 / 255.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let emptyBackgroundGradient = LinearGradient(
        colors: [
            Color(red: 226.0 / 255.0, green: 196.0 / 255.0, blue: 84.0 / 255.0),
            Color(red: 211.0 / 255.0, green: 166.0 / 255.0, blue: 41.0 / 255.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
