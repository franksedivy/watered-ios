//
//  EmptyTodayView.swift
//  Watered
//
//  Created by Frank Sedivy on 28/08/2026.
//

import SwiftUI

// MARK: - Empty Today View
/// Displays Today’s empty state; TodayView decides whether the day has no entries.
struct EmptyTodayView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(".. has been pretty dry so far")
                .font(.system(size: 44, weight: .light).leading(.tight))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            Text("No drinks logged yet today.")
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
        
    }
}

#Preview {
    EmptyTodayView()
        .padding()
        .background(Color.yellow)
}
