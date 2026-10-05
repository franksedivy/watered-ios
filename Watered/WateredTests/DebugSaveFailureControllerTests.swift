//
//  DebugSaveFailureControllerTests.swift
//  Watered
//
//  Created by Frank Sedivy on 05/10/2026.
//

#if DEBUG
import Foundation
import Testing
@testable import Watered

@MainActor
struct DebugSaveFailureControllerTests {
    // Given both failures are configured, when each save callback is called repeatedly,
    // then each throws once independently and subsequent calls succeed.
    @Test func configuredFailuresOccurOnceIndependently() throws {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "-uiTestingInMemory",
                "-uiTestingFailFirstDrinkSave",
                "-uiTestingFailFirstDisplayUnitSave"
            ]
        )
        let controller = DebugSaveFailureController(
            configuration: configuration
        )

        #expect(throws: CocoaError.self) {
            try controller.beforeDrinkSave()
        }
        try controller.beforeDrinkSave()

        #expect(throws: CocoaError.self) {
            try controller.beforeDisplayUnitSave()
        }
        try controller.beforeDisplayUnitSave()
        try controller.beforeDrinkSave()
    }
    
    // Given launches without enabled failures, when save callbacks run repeatedly,
    // then neither callback throws.
    @Test func unconfiguredSaveCallbacksSucceed() throws {
        let argumentSets: [[String]] = [
            [],
            ["-uiTestingInMemory"],
            ["-uiTestingFailFirstDrinkSave"],
            ["-uiTestingFailFirstDisplayUnitSave"],
            [
                "-uiTestingFailFirstDrinkSave",
                "-uiTestingFailFirstDisplayUnitSave"
            ]
        ]

        for arguments in argumentSets {
            let configuration = AppLaunchConfiguration(arguments: arguments)
            let controller = DebugSaveFailureController(
                configuration: configuration
            )

            try controller.beforeDrinkSave()
            try controller.beforeDisplayUnitSave()
            try controller.beforeDrinkSave()
            try controller.beforeDisplayUnitSave()
        }
    }
}
#endif
