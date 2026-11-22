//
//  AnalyticsEvent.swift
//  Watered
//
//  Created by Frank Sedivy on 02/10/2026.
//

/// Defines the product interactions Watered can report though its analytics boundary.
///
/// Events contain only explicitly allowed properies. Creating an even tdoe snot log, persist, or transmit it.
///
/// - Important: Do not include user identifiers, drink records or health data.
nonisolated enum AnalyticsEvent: Equatable {

    /// The user opened the Add Drink sheet
    case addDrinkOpened
    
    /// The user opened Apple Health permissions. No permission or Health properties.
    case appleHealthPermissionsOpened

    /// The user tapped Review permissions, independent of grants or request outcome.
    case appleHealthPermissionsReviewTapped

    /// A drink was successfully saved.
    ///
    /// - Parameter method: Whether the user submitted the form or tapped a recent drink.
    case drinkAdded(method: DrinkLoggingMethod)
    
    /// Identified the interaction used to log a drink, not the drink's contents.
    nonisolated enum DrinkLoggingMethod: String {
        /// The user submitted the Add Drink form.
        case form
        
        /// The user tapped a recent drink to add it immediately.
        case recent
    }
}
