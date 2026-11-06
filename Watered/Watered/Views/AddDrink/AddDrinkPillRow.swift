//
//  AddDrinkPillRow.swift
//  Watered
//
//  Created by Frank Sedivy on 03/09/2026.
//

import SwiftUI

/// A horizontal row of selectable options whose identity is independent of their labels.
struct AddDrinkPillRow<Option: Identifiable>: View {
    let options: [Option]
    let selectedID: Option.ID?
    let accessibilityIdentifier: String
    let optionLabel: (Option) -> String
    let onSelect: (Option) -> Void

    /// Creates a row of tappable options.
    ///
    /// - Parameters:
    ///   - options: Options in their display order.
    ///   - selectedID: The currently selected identity, or nil for direct-submit shortcuts.
    ///   - accessibilityIdentifier: Identifies the row and prefixes its option identifiers.
    ///   - optionLabel: Supplies display text without using it as identity.
    ///   - onSelect: Receives the selected option.
    init(
        options: [Option],
        selectedID: Option.ID? = nil,
        accessibilityIdentifier: String,
        optionLabel: @escaping (Option) -> String,
        onSelect: @escaping (Option) -> Void
    ) {
        self.options = options
        self.selectedID = selectedID
        self.accessibilityIdentifier = accessibilityIdentifier
        self.optionLabel = optionLabel
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    AddDrinkPillButton(
                        label: optionLabel(option),
                        isSelected: selectedID == option.id,
                        accessibilityIdentifier: "\(accessibilityIdentifier).\(option.id)",
                        onSelect: { onSelect(option) }
                    )
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// A shared pill for shortcuts, categories and inline drink choices.
struct AddDrinkPillButton: View {
    let label: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(label)
                .font(.callout)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.clear, in: Capsule())
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(PillButtonStyle(isSelected: isSelected))
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Preserves the resting pill appearance and supplies pressed-state feedback.
    private struct PillButtonStyle: ButtonStyle {
        let isSelected: Bool

        /// Styles the button while it is selected or pressed.
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isSelected || configuration.isPressed ? .white : .primary)
                .background(
                    isSelected || configuration.isPressed ? Color.accentColor : Color.clear,
                    in: Capsule()
                )
        }
    }
}
