//
//  TodayView.swift
//  Watered
//
//  Created by Frank Sedivy on 26/08/2026.
//

import SwiftUI


struct TodayView: View {
    // MARK: - Inputs
    
    /// The entries for the active day, supplied by the app shell; this view does not mutate history.
    let entries: [DrinkEntry]
    
    /// The applied display unit, used only to format volume values.
    let displayUnit: LiquidUnit
    
    /// Delegates Profile presentation to the app shell.
    let onOpenProfile: () -> Void
    
    // MARK: - Configuration
    
    /// The applied goal used by the tracker to derive progress and remaining hydration.
    let dailyGoal: HydrationGoal
    private let volumeFormatter = VolumeFormatter()
    private let progressFormatter = ProgressFormatter()
    
    // MARK: - Appearance
    /// Today-specific styling, owned separately from screen composition.
    private let appearance = TodayAppearance()
    
    // MARK: - Calculated Display Data

    /// Delegates hydration calculations for the supplied entries and goal to the model.
    private var tracker: HydrationTracker {
        HydrationTracker(
            entries: entries,
            dailyGoal: dailyGoal
        )
    }
    
    /// Formats the tracker snapshot for display using the applied unit.
    private var summary: HydrationSummaryViewData {
        return HydrationSummaryViewData(
            snapshot: tracker.snapshot,
            volumeFormatter: volumeFormatter,
            progressFormatter: progressFormatter,
            displayUnit: displayUnit
        )
    }
    
    // MARK: - Today Screen State
    
    private var screenBackgroundGradient: LinearGradient {
        appearance.backgroundGradient(for: todayScreenMode)
    }
    
    /// Selects empty state first, then goal reached, then first drink or in progress.
    /// Unknown progress cannot select the goal-reached state.
    private var todayScreenMode: TodayScreenMode {
        if entries.isEmpty {
            return .empty
        }
        
        if let actualProgressValue = summary.actualProgressValue {
            if actualProgressValue >= 1 {
                return .goalReached
            }
        }
        
        if entries.count == 1 {
            return .firstDrink
        }
        
        return .inProgress
    }
    
    // MARK: - Body
    
    /// Composes scrollable Today content and the shared Profile toolbar.
    var body: some View {
        NavigationStack {
            ZStack {
                screenBackgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        todayContentSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, appearance.screenHorizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ProfileToolbar(onOpenProfile: onOpenProfile)
            }
            .toolbarBackground(Color.clear, for: .navigationBar)
        }
        .accessibilityIdentifier("todayScreen")
    }
    
    // MARK: - Screen Content

    /// Routes the selected mode to its presentation without changing entries.
    @ViewBuilder
    private var todayContentSection: some View {
        switch todayScreenMode {
        case .empty:
            EmptyTodayView()
        case .firstDrink:
            FirstDrinkTodayView(summary: summary)
        case .inProgress:
            InProgressTodayView(drinkCount: entries.count, summary: summary)
        case .goalReached:
            GoalReachedTodayView(summary: summary)
        }
    }
}

#Preview {
    TodayView(
        entries: [],
        displayUnit: .milliliters,
        onOpenProfile: {},
        dailyGoal: HydrationGoal(
            amount:DrinkAmount(
                value: 2700,
                unit: .milliliters
            )
        )
    )
}
