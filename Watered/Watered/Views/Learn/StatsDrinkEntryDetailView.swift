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

    /// The app's applied volume unit; the entry retains its original stored unit.
    let displayUnit: LiquidUnit
    
    /// Requests deletion by entry ID. A thrown error keeps the view open and presents an alert.
    let onDeleteDrink: (UUID) throws -> Void
    
    /// Returns to Stats after a successful deletion.
    @Environment(\.dismiss) private var dismiss
    
    /// Controls the deletion confirmation dialog.
    @State private var isConfirmingDeletion = false
    
    /// Controls the alert shown when deletion fails.
    @State private var isShowingDeletionError = false

    /// The logged amount converted to the selected unit without changing stored values.
    private var amountText: String {
        VolumeFormatter().string(from: entry.amount.volume, displayedAs: displayUnit)
    }

    /// The saved contribution in the selected unit, retaining fractional precision.
    private var hydrationContributionText: String {
        guard let contribution = entry.hydrationContributionVolume else {
            return "Unknown"
        }
        return VolumeFormatter().string(from: contribution, displayedAs: displayUnit)
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

    /// Keeps unknown caffeine visible and hides only an explicitly known zero amount.
    private var showsCaffeineDetails: Bool {
        guard let amount = entry.catalogueSnapshot.caffeineAmount else {
            return true
        }
        return amount != 0
    }

    /// The saved estimate in milligrams, without replacing unknown amounts with zero.
    private var caffeineAmountText: String {
        guard let amount = entry.catalogueSnapshot.caffeineAmount else {
            return "Unknown"
        }
        return amount.formatted(.number.precision(.fractionLength(0...3))) + " mg"
    }

    /// The preparation captured when logging, independent of current catalogue options.
    private var caffeinePreparationText: String {
        switch entry.catalogueSnapshot.caffeineVariant {
        case .regular:
            return "Regular"
        case .decaf:
            return "Decaf"
        }
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
                LabeledContent("Amount", value: amountText)
                    .accessibilityIdentifier("statsDrinkAmount")
                LabeledContent("Source", value: entry.source.rawValue)
            }

            Section("Hydration") {
                LabeledContent("Contribution", value: hydrationContributionText)
                    .accessibilityIdentifier("statsHydrationContribution")
                LabeledContent("Hydration ratio", value: hydrationRatioText)
                    .accessibilityIdentifier("statsHydrationRatio")
            }

            if showsCaffeineDetails {
                Section("Caffeine") {
                    LabeledContent("Estimated caffeine", value: caffeineAmountText)
                        .accessibilityIdentifier("statsCaffeineAmount")
                    LabeledContent("Preparation", value: caffeinePreparationText)
                        .accessibilityIdentifier("statsCaffeinePreparation")
                    if let shotCount = entry.catalogueSnapshot.shotCount {
                        LabeledContent("Shots", value: String(shotCount))
                            .accessibilityIdentifier("statsCaffeineShotCount")
                    }
                }
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
                    Text("Delete \(amountText) of \(entry.displayName). This can't be undone.")
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
            displayUnit: .milliliters,
            onDeleteDrink: { entryID in
                wateredLog("Preview deletion requested for \(entryID)")
            }
        )
    }
}
#endif
