import Foundation

/// ABV choices for new logs; fractions are stored independently of hydration credit.
nonisolated struct AlcoholConfiguration: Codable, Equatable {
    let defaultABV: Double
    let supportedABVs: [Double]
    let nonAlcoholic: NonAlcoholicPreparation?

    init(defaultABV: Double, supportedABVs: [Double], nonAlcoholic: NonAlcoholicPreparation? = nil) {
        self.defaultABV = defaultABV
        self.supportedABVs = supportedABVs
        self.nonAlcoholic = nonAlcoholic
    }

    private enum CodingKeys: String, CodingKey { case defaultABV, supportedABVs, nonAlcoholic }

    init(from decoder: any Decoder) throws {
        try CatalogueObjectKeys.require(decoder, allowed: ["defaultABV", "supportedABVs", "nonAlcoholic"])
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultABV = try container.decode(Double.self, forKey: .defaultABV)
        supportedABVs = try container.decode([Double].self, forKey: .supportedABVs)
        nonAlcoholic = try container.decodeIfPresent(NonAlcoholicPreparation.self, forKey: .nonAlcoholic)
    }
}

/// An explicitly supported preparation with unknown exact ABV, bounded by its recipe scope.
nonisolated struct NonAlcoholicPreparation: Codable, Equatable {
    let hydrationRatio: Double
    let maximumABV: Double

    init(hydrationRatio: Double, maximumABV: Double) {
        self.hydrationRatio = hydrationRatio
        self.maximumABV = maximumABV
    }

    private enum CodingKeys: String, CodingKey { case hydrationRatio, maximumABV }

    init(from decoder: any Decoder) throws {
        try CatalogueObjectKeys.require(decoder, allowed: ["hydrationRatio", "maximumABV"])
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hydrationRatio = try container.decode(Double.self, forKey: .hydrationRatio)
        maximumABV = try container.decode(Double.self, forKey: .maximumABV)
    }
}
