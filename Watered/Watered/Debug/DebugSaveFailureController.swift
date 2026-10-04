//
//  DebugSaveFailureController.swift
//  Watered
//
//  Created by Frank Sedivy on 04/10/2026.
//

#if DEBUG
import Foundation

 /// Simulates each configured save failure once during this controller's lifetime.
///
/// The app owns one instance per launch. Persistence invokes its methods after mutation and before saving, so failure
/// exercises the rollback path.
@MainActor
final class DebugSaveFailureController {
    private var shouldFailDrinkSave: Bool
    private var shouldFailDisplayUnitSave: Bool
    
    /// Creates the controller using the validated launch configuration.
    ///
    /// - Parameter configuration: The requested isolated-testing behaviour.
    init(configuration: AppLaunchConfiguration) {
        shouldFailDrinkSave = configuration.shouldFailFirstDrinkSave
        shouldFailDisplayUnitSave = configuration.shouldFailFirstDisplayUnitSave
    }
    
    /// Throws once if a drink-save failure was requested.
    ///
    /// Consumes the failure before throwing so a retry can proceed normally.
    ///
    /// - Throws: A simulated file-write error on the first configured call.
    func beforeDrinkSave() throws {
        guard shouldFailDrinkSave else {
            return
        }
        
        shouldFailDrinkSave = false
        wateredLog("UI test: simulating the first drink save failure")
        throw CocoaError(.fileWriteUnknown)
    }
    
    /// Throws once if a display-unit save failure was requested.
    ///
    /// This failure is indepnedent of the drink-save failure.
    ///
    /// - Throws: A simulated file-write error on the first configured call.
    func beforeDisplayUnitSave() throws {
        guard shouldFailDisplayUnitSave else {
            return
        }
        
        shouldFailDisplayUnitSave = false
        wateredLog("UI test: simulating the first display-unit save failure")
        throw CocoaError(.fileWriteUnknown)
    }
}
#endif
