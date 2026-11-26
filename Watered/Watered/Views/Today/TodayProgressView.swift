//
//  TodayProgressView.swift
//  Watered
//
//  Created by Frank Sedivy on 27/08/2026.
//

import SwiftUI

// MARK: - Today Progress View
/// Displays prepared progress text and a visual progress value.
/// The caller supplies a value in 0...1; this view performs no hydration calculation or clamping.
struct TodayProgressView: View {
    let progressText: String
    let visualProgressValue: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text("0%")
                .font(.caption)
        
            ProgressView(value: visualProgressValue)
            
            Text("100%")
                .font(.caption)
            
            Text(progressText)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration progress")
        .accessibilityValue(progressText)
    }
}

#Preview {
    TodayProgressView(
        progressText: "54%",
        visualProgressValue: 0.54
    )
    .padding()
    .background(Color.blue)
}

