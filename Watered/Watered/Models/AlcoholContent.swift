import Foundation

/// Alcohol content, separate from hydration policy. ABV is a fraction: 0.05 means 5%.
nonisolated enum AlcoholContent: Codable, Equatable {
    case none
    case unknown
    case abv(Double)
    case options(AlcoholConfiguration)

    var configuration: AlcoholConfiguration? {
        if case .options(let configuration) = self { return configuration }
        return nil
    }

    private enum CodingKeys: String, CodingKey { case kind, value, configuration }
    private enum Kind: String, Codable { case none, unknown, abv, options }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .none, .unknown:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind"])
            self = kind == .none ? .none : .unknown
        case .options:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind", "configuration"])
            self = .options(try container.decode(AlcoholConfiguration.self, forKey: .configuration))
        case .abv:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind", "value"])
            let value = try container.decode(Double.self, forKey: .value)
            guard value.isFinite, (0...1).contains(value) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value, in: container, debugDescription: "ABV must be a finite fraction from 0 to 1."
                )
            }
            self = .abv(value)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try container.encode(Kind.none, forKey: .kind)
        case .unknown: try container.encode(Kind.unknown, forKey: .kind)
        case .options(let configuration):
            try container.encode(Kind.options, forKey: .kind)
            try container.encode(configuration, forKey: .configuration)
        case .abv(let value):
            try container.encode(Kind.abv, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}
