import Foundation

/// Estimated fraction of consumed volume that is water, not hydration goal credit.
nonisolated enum WaterContent: Codable, Equatable {
    case unknown
    case fraction(Double)

    private enum CodingKeys: String, CodingKey { case kind, value }
    private enum Kind: String, Codable { case unknown, fraction }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .unknown:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind"])
            self = .unknown
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
        case .fraction(let value):
            try container.encode(Kind.fraction, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}
