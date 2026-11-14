import Foundation

/// Pure alcohol quantity policy, separate from HealthKit authorization and sample creation.
nonisolated enum AlcoholExportQuantity {
    /// Watered's approved convention, not an Apple-defined mass conversion.
    static let policyVersion = "alcohol-14g-v1"
    static let ethanolGramsPerMilliliter = 0.789
    static let gramsPerStandardDrink = 14.0

    enum Result: Equatable {
        case standardDrinks(Double)
        case knownZero
        case unknown
        case invalid
    }

    /// Uses immutable saved volume and exact ABV, without catalogue lookup or display rounding.
    /// Upper-bound-only preparations remain unknown. Invalid facts never produce a quantity.
    static func resolve(_ entry: DrinkEntry) -> Result {
        let volume = VolumeCalculation.baseValue(from: entry.amount.volume)
        guard volume.isFinite, volume > 0 else { return .invalid }
        let snapshot = entry.catalogueSnapshot
        if let bound = snapshot.alcoholABVUpperBound {
            guard bound.isFinite, (0...1).contains(bound), snapshot.alcoholABV == nil else {
                return .invalid
            }
            return .unknown
        }
        guard let abv = snapshot.alcoholABV else { return .unknown }
        guard abv.isFinite, (0...1).contains(abv), (snapshot.isNonAlcoholic != true || abv == 0) else {
            return .invalid
        }
        guard abv > 0 else { return .knownZero }
        let count = volume * abv * ethanolGramsPerMilliliter / gramsPerStandardDrink
        guard count.isFinite, count > 0 else { return .invalid }
        return .standardDrinks(count)
    }
}
