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
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var healthExport: HealthExportCoordinator
    @State private var healthAuthorization: HealthAuthorizationController

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

    /// The bundled catalogue is loaded once; a failure must not prevent history access.
    private let catalogueResult: Result<DrinkCatalogue, Error>

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
        let usesFakeHealth = configuration.usesInMemoryStorage
            || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        var healthClient: any HealthExportClient = usesFakeHealth ? FakeHealthKitClient() : AppleHealthKitClient()
        var beforeHealthSave: () throws -> Void = {}
        #if DEBUG
        if configuration.usesInMemoryStorage, let scenario = configuration.healthTestScenario {
            let fixture = DebugHealthUITestClient(scenario: scenario)
            healthClient = fixture
            beforeHealthSave = fixture.beforeSave
        }
        #endif
        _healthExport = State(initialValue: HealthExportCoordinator(client: healthClient, beforeSave: beforeHealthSave))
        _healthAuthorization = State(initialValue: HealthAuthorizationController(client: healthClient))
        launchConfiguration = configuration
        catalogueResult = Result { try DrinkCatalogueLoader().load() }

        #if DEBUG
        _saveFailureController = State(
            initialValue: DebugSaveFailureController(configuration: configuration)
        )
        #endif
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                WateredRootView(
                    analytics: analytics,
                    catalogueResult: catalogueResult,
                    beforeDrinkSave: saveFailureController.beforeDrinkSave,
                    beforeDisplayUnitSave: saveFailureController.beforeDisplayUnitSave
                )
                #else
                WateredRootView(analytics: analytics, catalogueResult: catalogueResult)
                #endif
            }
            .environment(healthExport)
            .environment(healthAuthorization)
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { healthAuthorization.refreshAuthorization() }
            }
        }
        .modelContainer(
            for: [
                PersistentDrinkEntry.self,
                PersistentAppSettings.self,
                PersistentHydrationGoalChange.self,
                PersistentHealthExport.self,
                PersistentHealthSyncPreference.self
            ],
            inMemory: launchConfiguration.usesInMemoryStorage
        )
    }
}
