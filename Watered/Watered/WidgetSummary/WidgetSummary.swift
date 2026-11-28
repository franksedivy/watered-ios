import Foundation

/// Minimal v1 interchange values. Quantities are canonical millilitres, never formatted text.
/// Unknown hydration is an explicit null triplet; unavailable data is a separate read result.
nonisolated struct WidgetSummary: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: Double
    let dayStart: Double
    let dayEnd: Double
    let calendarIdentifier: String
    let timeZoneIdentifier: String
    let displayUnit: String
    let goalMillilitres: Double
    let hydrationMillilitres: Double?
    let remainingMillilitres: Double?
    let progressFraction: Double?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, generatedAt, dayStart, dayEnd, calendarIdentifier
        case timeZoneIdentifier, displayUnit, goalMillilitres, hydrationMillilitres
        case remainingMillilitres, progressFraction
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        generatedAt = try values.decode(Double.self, forKey: .generatedAt)
        dayStart = try values.decode(Double.self, forKey: .dayStart)
        dayEnd = try values.decode(Double.self, forKey: .dayEnd)
        calendarIdentifier = try values.decode(String.self, forKey: .calendarIdentifier)
        timeZoneIdentifier = try values.decode(String.self, forKey: .timeZoneIdentifier)
        displayUnit = try values.decode(String.self, forKey: .displayUnit)
        goalMillilitres = try values.decode(Double.self, forKey: .goalMillilitres)
        // decode(Optional.self) requires the key, unlike decodeIfPresent.
        hydrationMillilitres = try values.decode(Double?.self, forKey: .hydrationMillilitres)
        remainingMillilitres = try values.decode(Double?.self, forKey: .remainingMillilitres)
        progressFraction = try values.decode(Double?.self, forKey: .progressFraction)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(generatedAt, forKey: .generatedAt)
        try values.encode(dayStart, forKey: .dayStart)
        try values.encode(dayEnd, forKey: .dayEnd)
        try values.encode(calendarIdentifier, forKey: .calendarIdentifier)
        try values.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try values.encode(displayUnit, forKey: .displayUnit)
        try values.encode(goalMillilitres, forKey: .goalMillilitres)
        try values.encode(hydrationMillilitres, forKey: .hydrationMillilitres)
        try values.encode(remainingMillilitres, forKey: .remainingMillilitres)
        try values.encode(progressFraction, forKey: .progressFraction)
    }

    /// Checks the caller's current calendar day exactly; no fixed day duration or age expiry.
    func isValid(at now: Date, calendar: Calendar) -> Bool {
        guard schemaVersion == 1,
              [generatedAt, dayStart, dayEnd, goalMillilitres, now.timeIntervalSince1970].allSatisfy(\.isFinite),
              goalMillilitres > 0, dayStart < dayEnd,
              generatedAt >= dayStart, generatedAt < dayEnd, generatedAt <= now.timeIntervalSince1970,
              LiquidUnit(persistenceIdentifier: displayUnit) != nil,
              TimeZone(identifier: timeZoneIdentifier) != nil,
              calendarIdentifier == String(describing: calendar.identifier),
              timeZoneIdentifier == calendar.timeZone.identifier,
              let day = calendar.dateInterval(of: .day, for: now),
              dayStart == day.start.timeIntervalSince1970,
              dayEnd == day.end.timeIntervalSince1970 else { return false }

        switch (hydrationMillilitres, remainingMillilitres, progressFraction) {
        case (nil, nil, nil):
            return true
        case let (hydration?, remaining?, progress?):
            let expectedRemaining = max(goalMillilitres - hydration, 0)
            let expectedProgress = hydration / goalMillilitres
            return [hydration, remaining, progress, expectedRemaining, expectedProgress].allSatisfy(\.isFinite)
                && remaining >= 0
                && Self.approximatelyEqual(remaining, expectedRemaining)
                && Self.approximatelyEqual(progress, expectedProgress)
        default:
            return false
        }
    }

    /// Absolute tolerance 1e-9 near zero, relative tolerance 1e-9 otherwise.
    private static func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 1e-9 * max(1, abs(lhs), abs(rhs))
    }
}

nonisolated enum WidgetSummaryReadResult: Equatable {
    case available(WidgetSummary)
    case unavailable
}

/// JSON boundary only. The future file reader must bound I/O before allocating its Data.
nonisolated enum WidgetSummaryCodec {
    static let maximumPayloadBytes = 64 * 1024

    static func decode(_ data: Data?, at now: Date, calendar: Calendar) -> WidgetSummaryReadResult {
        guard let data, data.count <= maximumPayloadBytes,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(WidgetSummary.CodingKeys.allCases.map(\.rawValue)),
              let summary = try? JSONDecoder().decode(WidgetSummary.self, from: data),
              summary.isValid(at: now, calendar: calendar) else { return .unavailable }
        return .available(summary)
    }

    static func encode(_ summary: WidgetSummary, at now: Date, calendar: Calendar) throws -> Data {
        guard summary.isValid(at: now, calendar: calendar) else { throw EncodingFailure.invalidSummary }
        let data = try JSONEncoder().encode(summary)
        guard data.count <= maximumPayloadBytes else { throw EncodingFailure.invalidSummary }
        return data
    }

    enum EncodingFailure: Error { case invalidSummary }
}
