//
//  AddDrinkSubmissionMethod.swift
//  Watered
//
//  Created by Frank Sedivy on 03/10/2026.
//

/// Identifies how a dirnk was submitted through the Add Drink sheet.
///
/// This describes a UI interaction, not the drink's persisted source or contents.
nonisolated enum AddDrinkSubmissionMethod {
    /// The user confirmed the current form selections.
    case form
    
    /// The user tapped a recent-drink shortcut.
    case recent
}
