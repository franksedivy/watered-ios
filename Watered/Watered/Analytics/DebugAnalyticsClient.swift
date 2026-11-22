//
//  DebugAnalyticsClient.swift
//  Watered
//
//  Created by Frank Sedivy on 02/10/2026.
//

#if DEBUG

/// Writes analytics events to Watered's local debug log.
///
/// This client is avialable only in Debug builds. It does not send events to an analytics provider or maintain an event history.
@MainActor
struct DebugAnalyticsClient: AnalyticsClient {
    
    /// Logs the event name and its explicitly allowed properties.
    ///
    /// - Parameter event: The product interaction to describe in the debug log.
    func track(_ event: AnalyticsEvent) {
        switch event {
        case .addDrinkOpened:
            wateredLog("Analytics: add_drink_opened")
        case .appleHealthPermissionsOpened:
            wateredLog("Analytics: apple_health_permissions_opened")
        case .appleHealthPermissionsReviewTapped:
            wateredLog("Analytics: apple_health_permissions_review_tapped")
        case .drinkAdded(let method):
            wateredLog("Analytics: drink_added | method: \(method.rawValue)")
        }
    }
}

#endif
