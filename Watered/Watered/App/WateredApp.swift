//
//  WateredApp.swift
//  Watered
//
//  Created by Frank Sedivy on 26/06/2026.
//

import SwiftUI
import SwiftData

@main
struct WateredApp: App {
    
    // MARK: - Dependencies
    
    /// Selects the analytics implementation for the current build.
    ///
    /// Debug builds report events through the local debug log.
    /// Release builds discard events. Neither implementation sends network data.
    private var analytics: any AnalyticsClient {
        #if DEBUG
        return DebugAnalyticsClient()
        #else
        return NoOpAnalyticsClient()
        #endif
    }
    
    // MARK: - Launch Configuration

    /// Determines storage and test behaviour from this launch's arguments.
    private let launchConfiguration: AppLaunchConfiguration

    #if DEBUG
    /// Retains one failure controller across SwiftUI view updates.
    @State private var saveFailureController: DebugSaveFailureController
    #endif

    /// Reads launch configuration and creates Debug-only failure state.
    @MainActor
    init() {
        let configuration = AppLaunchConfiguration(
            arguments: ProcessInfo.processInfo.arguments
        )
        launchConfiguration = configuration

        #if DEBUG
        _saveFailureController = State(
            initialValue: DebugSaveFailureController(configuration: configuration)
        )
        #endif
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            WateredRootView(
                analytics: analytics,
                beforeDrinkSave: saveFailureController.beforeDrinkSave,
                beforeDisplayUnitSave: saveFailureController.beforeDisplayUnitSave
            )
            #else
            WateredRootView(analytics: analytics)
            #endif
        }
        .modelContainer(
            for: [
                PersistentDrinkEntry.self,
                PersistentAppSettings.self,
                PersistentHydrationGoalChange.self
            ],
            inMemory: launchConfiguration.usesInMemoryStorage
        )
    }
}
