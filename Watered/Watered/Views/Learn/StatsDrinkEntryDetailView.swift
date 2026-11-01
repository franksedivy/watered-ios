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
/// Presented from Stats so captured estimates, catalogue provenance and dates can be inspected.
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

    /// The saved contribution in millilitres, retaining fractional values for inspection.
    private var hydrationContributionText: String {
        guard let contribution = entry.catalogueSnapshot.hydrationContribution else {
            return "Unknown"
        }
        return contribution.formatted(.number.precision(.fractionLength(0...3))) + " ml"
    }

    /// The effective saved ratio as a fraction and percentage, without clamping its sign.
    private var hydrationRatioText: String {
        guard let ratio = entry.hydrationContributionRatio else {
            return "Unknown"
        }
        let fraction = ratio.formatted(.number.precision(.fractionLength(0...6)))
        let percentage = ratio.formatted(.percent.precision(.fractionLength(0...2)))
        return "\(fraction) (\(percentage))"
    }

    /// The original schema version, without inferring it from the current catalogue.
    private var schemaVersionText: String {
        guard let version = entry.catalogueSnapshot.catalogueSchemaVersion else {
            return "Not recorded"
        }
        return String(version)
    }
    
    var body: some View {
        List {
            Section("Drink") {
                LabeledContent("Type", value: entry.displayName)
                LabeledContent("Amount", value: entry.amount.formatted)
                LabeledContent("Source", value: entry.source.rawValue)
            }

            Section("Hydration") {
                LabeledContent("Contribution", value: hydrationContributionText)
                    .accessibilityIdentifier("statsHydrationContribution")
                LabeledContent("Hydration ratio", value: hydrationRatioText)
                    .accessibilityIdentifier("statsHydrationRatio")
            }
            
            Section("Identity") {
                LabeledContent("ID", value: entry.id.uuidString)
            }

            Section("Catalogue") {
                LabeledContent("Drink ID", value: entry.drinkID)
                LabeledContent("JSON version", value: entry.catalogueSnapshot.catalogueVersion)
                    .accessibilityIdentifier("statsCatalogueVersion")
                LabeledContent("Schema version", value: schemaVersionText)
                    .accessibilityIdentifier("statsCatalogueSchemaVersion")
                LabeledContent("Calculation version", value: entry.catalogueSnapshot.calculationVersion)
                    .accessibilityIdentifier("statsCalculationVersion")
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
        .accessibilityIdentifier("statsDrinkEntryDetailList")
        .navigationTitle(entry.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        StatsDrinkEntryDetailView(
            entry: DrinkPreviewData.entry(
                drinkID: "still-water",
                amount: DrinkAmount(value: 300, unit: .milliliters),
                date: Date()
            ),
            onDeleteDrink: { entryID in
                wateredLog("Preview deletion requested for \(entryID)")
            }
        )
    }
}
#endif
