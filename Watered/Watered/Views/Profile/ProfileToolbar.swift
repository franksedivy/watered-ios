//
//  ProfileToolbar.swift
//  Watered
//
//  Created by Frank Sedivy on 26/08/2026.
//

import SwiftUI

// MARK: - Profile Toolbar View
/// Provides the shared Profile toolbar button; the parent owns sheet presentation.
struct ProfileToolbar: ToolbarContent {
    // MARK: - Actions
    /// Delegates opening Profile to the presenting screen.
    private let onOpenProfile: () -> Void
    
    // MARK: - Initialisation
    
    init(onOpenProfile: @escaping () -> Void) {
        self.onOpenProfile = onOpenProfile
    }
    
    // MARK: - Body
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onOpenProfile) {
                Text("FS")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
            .accessibilityHint("Opens Profile settings.")
            .accessibilityIdentifier("profileButton")
        }
    }
}

#Preview {
    NavigationStack {
        Color.blue
            .ignoresSafeArea()
            .navigationTitle(Text("Preview"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ProfileToolbar(onOpenProfile: {})
            }
    }
}
