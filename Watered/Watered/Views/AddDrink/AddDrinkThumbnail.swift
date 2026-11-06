//
//  AddDrinkThumbnail.swift
//  Watered
//

import SwiftUI
import UIKit

/// Displays bundled artwork named by catalogue ID, with an illustration when artwork is absent.
struct AddDrinkThumbnail: View {
    let drinkID: String
    let categoryID: String

    private var liquidColor: Color {
        switch drinkID {
        case "infused-water": return Color(red: 0.78, green: 0.83, blue: 0.39)
        case "coconut-water": return Color(red: 0.90, green: 0.81, blue: 0.75)
        case "latte", "coffee-with-milk": return Color(red: 0.72, green: 0.43, blue: 0.22)
        case "cappuccino", "frappe": return Color(red: 0.83, green: 0.65, blue: 0.43)
        case "espresso", "americano", "turkish-coffee", "cold-brew", "decaf-coffee":
            return Color(red: 0.28, green: 0.12, blue: 0.04)
        case "mocha": return Color(red: 0.40, green: 0.22, blue: 0.11)
        case "iced-coffee": return Color(red: 0.57, green: 0.33, blue: 0.18)
        default: return categoryID == "water" ? Color(red: 0.40, green: 0.70, blue: 0.88) : .brown
        }
    }

    var body: some View {
        Group {
            if let artwork = UIImage(named: drinkID) {
                Image(uiImage: artwork)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            Circle()
                .fill(RadialGradient(
                    colors: [liquidColor.opacity(0.65), liquidColor, liquidColor.opacity(0.8)],
                    center: .init(x: 0.35, y: 0.25), startRadius: 0, endRadius: 46
                ))
                .padding(5)
            surfaceDetails
                .padding(9)
                .clipShape(Circle())
            Circle()
                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                .padding(2)
            Circle()
                .strokeBorder(liquidColor.opacity(0.65), lineWidth: 1)
                .padding(5)
            Circle()
                .trim(from: 0.55, to: 0.88)
                .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-30))
                .padding(8)
        }
    }

    @ViewBuilder
    private var surfaceDetails: some View {
        if drinkID == "sparkling-water" || drinkID == "mineral-water" {
            Canvas { context, size in
                for index in 0..<22 {
                    let x = CGFloat((index * 17 + 7) % 47) / 47 * size.width
                    let y = CGFloat((index * 23 + 3) % 47) / 47 * size.height
                    let radius: CGFloat = index.isMultiple(of: 3) ? 2.2 : 1.1
                    let bubble = Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
                    context.stroke(bubble, with: .color(.white.opacity(0.8)), lineWidth: 0.7)
                }
            }
        } else if drinkID == "latte" || drinkID == "coffee-with-milk" {
            // A simple milk rosetta, intentionally illustrative rather than photographic.
            Canvas { context, size in
                for index in 0..<6 {
                    let width = size.width * (0.78 - CGFloat(index) * 0.09)
                    let leaf = Path(ellipseIn: CGRect(
                        x: (size.width - width) / 2,
                        y: size.height * 0.18 + CGFloat(index) * size.height * 0.095,
                        width: width, height: size.height * 0.13
                    ))
                    context.fill(leaf, with: .color(.white.opacity(0.88)))
                }
                var stem = Path()
                stem.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.18))
                stem.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.84))
                context.stroke(stem, with: .color(.white.opacity(0.9)), lineWidth: 2)
            }
        } else if drinkID == "cappuccino" || drinkID == "frappe" {
            Circle().fill(.white.opacity(0.8)).padding(3)
                .overlay {
                    Circle().trim(from: 0.1, to: 0.8)
                        .stroke(liquidColor.opacity(0.5), lineWidth: 3).padding(9)
                }
        } else if drinkID == "iced-coffee" || drinkID == "cold-brew" {
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.4))
                    .rotationEffect(.degrees(18))
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.3))
                    .rotationEffect(.degrees(-22))
            }
            .frame(height: 23)
            .padding(6)
        } else if drinkID == "infused-water" {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green.opacity(0.6))
                .rotationEffect(.degrees(-25))
        }
    }
}
