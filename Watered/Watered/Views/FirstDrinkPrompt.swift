//
//  FirstDrinkPrompt.swift
//  Watered
//
//  Created by Frank Sedivy on 30/08/2026.
//

import SwiftUI

// MARK: - First Drink Prompt
/// Displays the first-drink prompt beside the app-level Add Drink action.
/// The parent decides when it is visible.
struct FirstDrinkPrompt: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text("Go on, log\nyour first drink")
                .font(.system(size: 17, weight: .regular))
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Image(systemName: "arrow.down.right")
                .font(.system(size: 17, weight: .regular))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    FirstDrinkPrompt()
        .padding()
}
