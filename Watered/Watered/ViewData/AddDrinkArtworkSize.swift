import Foundation

/// Artwork bounds inside Add Drink's fixed cell, independent of serving size or preparation.
nonisolated enum AddDrinkArtworkSize {
    case small
    case medium
    case large

    var dimension: CGFloat {
        switch self {
        case .small: return 54
        case .medium: return 64
        case .large: return 74
        }
    }

    /// Local presentation hints use the same stable IDs as bundled artwork.
    /// Unconfigured and new drinks retain the large default without catalogue schema changes.
    static func resolve(drinkID: String) -> Self {
        hints[drinkID] ?? .large
    }

    private static let hints: [String: Self] = [
        "espresso": .small,
        "sparkling-wine": .medium
    ]
}
