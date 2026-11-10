import Foundation

/// Estimated fraction of consumed volume that is water, not hydration goal credit.
nonisolated enum WaterContent: Codable, Equatable {
    case unknown
    case fraction(Double)

    case alcoholOptions([AlcoholWaterOption], nonAlcoholic: Double?)

    struct AlcoholWaterOption: Codable, Equatable {
        let abv: Double
        let fraction: Double

        init(abv: Double, fraction: Double) {
            self.abv = abv
            self.fraction = fraction
        }

        private enum CodingKeys: String, CodingKey { case abv, fraction }
        init(from decoder: any Decoder) throws {
            try CatalogueObjectKeys.require(decoder, allowed: ["abv", "fraction"])
            let container = try decoder.container(keyedBy: CodingKeys.self)
            abv = try container.decode(Double.self, forKey: .abv)
            fraction = try container.decode(Double.self, forKey: .fraction)
            guard abv.isFinite, abv > 0, abv <= 1,
                  fraction.isFinite, (0...1).contains(fraction) else {
                throw DecodingError.dataCorruptedError(forKey: .fraction, in: container,
                    debugDescription: "Invalid alcohol water option.")
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case kind, value, options, nonAlcoholic }
    private enum Kind: String, Codable { case unknown, fraction, alcoholOptions }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .unknown:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind"])
            self = .unknown
        case .alcoholOptions:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind", "options", "nonAlcoholic"])
            let options = try container.decode([AlcoholWaterOption].self, forKey: .options)
            let nonAlcoholic = try container.decodeIfPresent(Double.self, forKey: .nonAlcoholic)
            guard !options.isEmpty, Set(options.map(\.abv)).count == options.count,
                  nonAlcoholic.map({ $0.isFinite && (0...1).contains($0) }) ?? true else {
                throw DecodingError.dataCorruptedError(forKey: .options, in: container,
                    debugDescription: "Invalid alcohol water options.")
            }
            self = .alcoholOptions(options, nonAlcoholic: nonAlcoholic)
        case .fraction:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind", "value"])
            let value = try container.decode(Double.self, forKey: .value)
            guard value.isFinite, (0...1).contains(value) else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container,
                    debugDescription: "Water content must be a finite fraction from 0 to 1.")
            }
            self = .fraction(value)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unknown:
            try container.encode(Kind.unknown, forKey: .kind)
        case .alcoholOptions(let options, let nonAlcoholic):
            try container.encode(Kind.alcoholOptions, forKey: .kind)
            try container.encode(options, forKey: .options)
            try container.encodeIfPresent(nonAlcoholic, forKey: .nonAlcoholic)
        case .fraction(let value):
            try container.encode(Kind.fraction, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}
