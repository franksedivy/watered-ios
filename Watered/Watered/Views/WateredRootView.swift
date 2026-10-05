//
//  WateredRootView.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

// MARK: - Watered Root View

/// Defines Watere's root experience and forwards app-level dependencies
///
/// The tab view owns navigation and sheet presentation. This view connnects that app shell to the dependencies supplied
/// at launch.
struct WateredRootView: View {
    
    // MARK: - Dependencies
    
    /// The analytics client passed to the app shell.
    private let analytics: any AnalyticsClient
    
    /// The drink-save callback forwarded to the app shell.
    private let beforeDrinkSave: () throws -> Void
    
    /// The display-unit save callback forwarded to the app shell.
    private let beforeDisplayUnitSave: () throws -> Void
    
    // MARK: - Initialisation
    
    /// Creates the root experience without analytics reporting
    @MainActor
    init() {
        self.init(analytics: NoOpAnalyticsClient())
    }
    
    /// Creates the root experience with the supplied app dependencies.
    ///
    /// - Parameters:
    ///   - analytics: The client forwarded to the app shell.
    ///   - beforeDrinkSave: An action run before saving an inserted drink.
    ///   - beforeDisplayUnitSave: An action run before saving a changed display unit.
    @MainActor
    init(
        analytics: any AnalyticsClient,
        beforeDrinkSave: @escaping () throws -> Void = {},
        beforeDisplayUnitSave: @escaping () throws -> Void = {}
    ) {
        self.analytics = analytics
        self.beforeDrinkSave = beforeDrinkSave
        self.beforeDisplayUnitSave = beforeDisplayUnitSave
    }
    
    // MARK: - Body
    
    var body: some View {
        WateredTabView(
            analytics: analytics,
            beforeDrinkSave: beforeDrinkSave,
            beforeDisplayUnitSave: beforeDisplayUnitSave
        )
    }
}

#Preview {
    WateredRootView()
}
