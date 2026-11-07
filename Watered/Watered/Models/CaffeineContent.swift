import Foundation

/// Catalogue caffeine content. Absence is known zero; unknown is never inferred as zero.
nonisolated enum CaffeineContent: Codable, Equatable {
    case none
    case unknown
    case options(defaultVariant: CaffeineVariant, options: [CaffeineOption])

    /// Adapts content to the existing preparation/resolution contract without storing duplicate facts.
    var options: [CaffeineOption] {
        switch self {
        case .none: return [CaffeineOption(variant: .regular, rule: .perVolume(concentration: 0))]
        case .unknown: return [CaffeineOption(variant: .regular, rule: .unknown)]
        case .options(_, let options): return options
        }
    }

    var defaultVariant: CaffeineVariant {
        if case .options(let variant, _) = self { return variant }
        return .regular
    }

    private enum CodingKeys: String, CodingKey { case kind, defaultVariant, options }
    private enum Kind: String, Codable { case none, unknown, options }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .none, .unknown:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind"])
            self = kind == .none ? .none : .unknown
        case .options:
            try CatalogueObjectKeys.require(decoder, allowed: ["kind", "defaultVariant", "options"])
            self = .options(
                defaultVariant: try container.decode(CaffeineVariant.self, forKey: .defaultVariant),
                options: try container.decode([CaffeineOption].self, forKey: .options)
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try container.encode(Kind.none, forKey: .kind)
        case .unknown: try container.encode(Kind.unknown, forKey: .kind)
        case .options(let variant, let options):
            try container.encode(Kind.options, forKey: .kind)
            try container.encode(variant, forKey: .defaultVariant)
            try container.encode(options, forKey: .options)
        }
    }
}

/// Rejects extra fields in tagged catalogue objects rather than silently ignoring contradictory data.
nonisolated struct CatalogueObjectKeys: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }

    static func require(_ decoder: any Decoder, allowed: Set<String>) throws {
        let container = try decoder.container(keyedBy: Self.self)
        guard container.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Unexpected fields in catalogue object."
            ))
        }
    }
}
