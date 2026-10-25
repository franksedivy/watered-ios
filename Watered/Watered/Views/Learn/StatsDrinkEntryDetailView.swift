//
//  StatsDrinkEntryDetailView.swift
//  Watered
//
//  Created by Frank Sedivy on 06/09/2026.
//

import SwiftUI

// MARK: - Stats Drink Entry Detail View

/// Shows a logged drink's stored details and provides a deletion action.
///
/// Presented from Stats so the drink's identity, dates, and source can be inspected.
struct StatsDrinkEntryDetailView: View {
    let entry: DrinkEntry
    
    /// Requests deletion by entry ID. A thrown error keeps the view open and presents an alert.
    let onDeleteDrink: (UUID) throws -> Void
    
    /// Returns to Stats after a successful deletion.
    @Environment(\.dismiss) private var dismiss
    
    /// Controls the deletion confirmation dialog.
    @State private var isConfirmingDeletion = false
    
    /// Controls the alert shown when deletion fails.
    @State private var isShowingDeletionError = false
    
    var body: some View {
        List {
            Section("Drink") {
                LabeledContent("Type", value: entry.displayName)
                LabeledContent("Amount", value: entry.amount.formatted)
                LabeledContent("Source", value: entry.source.rawValue)
            }
            
            Section("Identity") {
                LabeledContent("ID", value: entry.id.uuidString)
            }
            
            Section("Dates") {
                LabeledContent("Logged at", value: entry.loggedAt.formatted(date: .complete, time: .complete))
                LabeledContent("Created at", value: entry.createdAt.formatted(date: .complete, time: .complete))
                LabeledContent("Updated at", value: entry.updatedAt.formatted(date: .complete, time: .complete))
            }
            Section {
                Button(role: .destructive) {
                    isConfirmingDeletion = true
                } label: {
                    Label("Delete drink", systemImage: "trash")
                }
                .accessibilityIdentifier("deleteDrinkButton")
                
                .confirmationDialog(
                    "Delete this drink?",
                    isPresented: $isConfirmingDeletion,
                    titleVisibility: .visible
                ) {
                    Button("Delete drink", role: .destructive) {
                        do {
                            try onDeleteDrink(entry.id)
                            dismiss()
                        } catch {
                            wateredLog("Drink deletion failed for \(entry.id): \(error.localizedDescription)")
                            isShowingDeletionError = true
                        }
                    }
                    .accessibilityIdentifier("confirmDeleteDrinkButton")
                    
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Delete \(entry.amount.formatted) of \(entry.displayName). This can't be undone.")
                }
                .alert(
                    "Could not delete drink",
                    isPresented: $isShowingDeletionError
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("The drink could not be deleted.")
                }
            }
        }
        .navigationTitle(entry.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StatsDrinkEntryDetailView(
            entry: DrinkEntry(
                type: .water,
                amount: DrinkAmount(value: 300, unit: .milliliters),
                date: Date()
            ),
            onDeleteDrink: { entryID in
                wateredLog("Preview deletion requested for \(entryID)")
            }
        )
    }
}
