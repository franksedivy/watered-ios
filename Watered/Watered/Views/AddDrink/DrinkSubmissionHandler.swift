//
//  DrinkSubmissionHandler.swift
//  Watered
//
//  Created by Frank Sedivy on 03/10/2026.
//

/// Coordinates saving a submitted drink, updating the app state and recording success.
///
/// The caller supplies persistence behaviour and handles errors and sheet presentation.
@MainActor
struct DrinkSubmissionHandler {
    private let store: WateredStore
    private let analytics: any AnalyticsClient
    
    /// Creates a handler using the app's existing state and analyticas client.
    ///
    /// - Parameters:
    ///  - store: The In-memory drink store updated after saving succeeds.
    ///  - analytics: The client that recieves successful submission events.
    init(store: WateredStore, analytics: any AnalyticsClient) {
        self.store = store
        self.analytics = analytics
    }
    
    /// Saves a drink before updating state and recording its submission method.
    ///
    /// - Parameters:
    ///  - entry: The drink to save.
    ///  - method: Whether submission came from the form or a recent-drink shortcut.
    ///  - save: Persists the entry, returning only after saving succeeds.
    /// - Throws: The error reported by the supplied save operation.
    /// - Important: The save operation must clean up pending changes if it fails.
    /// A thrown error prevents this handler from updating state or recording success.
    func submit(
        _ entry: DrinkEntry,
        method: AddDrinkSubmissionMethod,
        save: (DrinkEntry) throws -> Void
    ) throws {
        try save(entry)
        
        store.addDrinkEntry(entry)
        
        switch method {
        case .form:
            analytics.track(.drinkAdded(method: .form))
        case .recent:
            analytics.track(.drinkAdded(method: .recent))
        }
    }
}
