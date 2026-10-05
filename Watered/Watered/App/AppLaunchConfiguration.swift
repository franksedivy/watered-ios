//
//  AppLaunchConfiguration.swift
//  Watered
//
//  Created by Frank Sedivy on 04/10/2026.
//

/// Interprets launch arguments for isolated UI testing.
///
/// Failure simulation requires in-memory storage. Release builds ignore all test arguments
/// and use normal persistent storage.
struct AppLaunchConfiguration {
    /// Whether the app should use an isolated, in-memory store.
    let usesInMemoryStorage: Bool
    
    /// Whether the first drink save should fail before saving.
    let shouldFailFirstDrinkSave: Bool
    
    /// Whether the first display-unit save should fail before saving.
    let shouldFailFirstDisplayUnitSave: Bool
    
    /// Creates a configuration from the supplied launch arguments.
    ///
    /// Supplying arguments explicitly keeps configuration tests independent of the running process.
    ///
    /// - Parameter arguments: The arguments supplied when launching the app.
    init(arguments: [String]) {
        #if DEBUG
        let usesIsolatedStorage = arguments.contains("-uiTestingInMemory")
        
        usesInMemoryStorage = usesIsolatedStorage
        shouldFailFirstDrinkSave = usesIsolatedStorage
            && arguments.contains("-uiTestingFailFirstDrinkSave")
        shouldFailFirstDisplayUnitSave = usesIsolatedStorage
            && arguments.contains("-uiTestingFailFirstDisplayUnitSave")
        #else
        usesInMemoryStorage = false
        shouldFailFirstDrinkSave = false
        shouldFailFirstDisplayUnitSave = false
        #endif
    }
}
