//
//  AppLaunchConfigurationTests.swift
//  Watered
//
//  Created by Frank Sedivy on 05/10/2026.
//

import Testing
@testable import Watered

@MainActor
struct AppLaunchConfigurationTests {
    // Given launch arguments without isolated storage, when configuration is read,
    // then persistent storage is used and neither simulated failure is enabled.
    @Test func failureRequestsRequireIsolatedStorage() {
        let argumentSets: [[String]] = [
            [],
            ["-uiTestingFailFirstDrinkSave"],
            ["-uiTestingFailFirstDisplayUnitSave"],
            [
                "-uiTestingFailFirstDrinkSave",
                "-uiTestingFailFirstDisplayUnitSave"
            ]
        ]

        for arguments in argumentSets {
            let configuration = AppLaunchConfiguration(arguments: arguments)

            #expect(configuration.usesInMemoryStorage == false)
            #expect(configuration.shouldFailFirstDrinkSave == false)
            #expect(configuration.shouldFailFirstDisplayUnitSave == false)
        }
    }
    
    #if DEBUG
    // Given isolated-storage launch arguments, when failures are configured,
    // then only the explicitly requested failures are enabled.
    @Test func isolatedLaunchEnablesOnlyRequestedFailures() {
        let storageOnly = AppLaunchConfiguration(
            arguments: ["-uiTestingInMemory"]
        )
        #expect(storageOnly.usesInMemoryStorage)
        #expect(storageOnly.shouldFailFirstDrinkSave == false)
        #expect(storageOnly.shouldFailFirstDisplayUnitSave == false)

        let drinkFailure = AppLaunchConfiguration(
            arguments: [
                "-uiTestingInMemory",
                "-uiTestingFailFirstDrinkSave"
            ]
        )
        #expect(drinkFailure.usesInMemoryStorage)
        #expect(drinkFailure.shouldFailFirstDrinkSave)
        #expect(drinkFailure.shouldFailFirstDisplayUnitSave == false)

        let unitFailure = AppLaunchConfiguration(
            arguments: [
                "-uiTestingInMemory",
                "-uiTestingFailFirstDisplayUnitSave"
            ]
        )
        #expect(unitFailure.usesInMemoryStorage)
        #expect(unitFailure.shouldFailFirstDrinkSave == false)
        #expect(unitFailure.shouldFailFirstDisplayUnitSave)

        let bothFailures = AppLaunchConfiguration(
            arguments: [
                "-uiTestingInMemory",
                "-uiTestingFailFirstDrinkSave",
                "-uiTestingFailFirstDisplayUnitSave"
            ]
        )
        #expect(bothFailures.usesInMemoryStorage)
        #expect(bothFailures.shouldFailFirstDrinkSave)
        #expect(bothFailures.shouldFailFirstDisplayUnitSave)
    }
    #endif
    
    #if !DEBUG
    // Given a Release build with all UI-test arguments, when configuration is read,
    // then persistent storage remains enabled and simulated failures stay disabled.
    @Test func releaseIgnoresUITestArguments() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "-uiTestingInMemory",
                "-uiTestingFailFirstDrinkSave",
                "-uiTestingFailFirstDisplayUnitSave"
            ]
        )

        #expect(configuration.usesInMemoryStorage == false)
        #expect(configuration.shouldFailFirstDrinkSave == false)
        #expect(configuration.shouldFailFirstDisplayUnitSave == false)
    }
    #endif
}
