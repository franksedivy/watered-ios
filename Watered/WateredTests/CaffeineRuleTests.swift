//
//  CaffeineRuleTests.swift
//  Watered
//
//  Created by Frank Sedivy on 10/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct CaffeineRuleTests {
    // GIVEN JSON describing a volume-based caffeine rule,
    // WHEN the rule is decoded,
    // THEN its concentration is preserved.
    @Test func decodesPerVolumeRule() throws {
        let json = """
        {"kind": "perVolume", "concentration": 12.5}
        """

        let rule = try JSONDecoder().decode(
            CaffeineRule.self,
            from: Data(json.utf8)
        )

        #expect(rule == .perVolume(concentration: 12.5))
    }

    // GIVEN JSON describing a shot-based caffeine rule,
    // WHEN the rule is decoded,
    // THEN its amount per shot is preserved.
    @Test func decodesPerShotRule() throws {
        let json = """
        {"kind": "perShot", "amount": 60}
        """

        let rule = try JSONDecoder().decode(
            CaffeineRule.self,
            from: Data(json.utf8)
        )

        #expect(rule == .perShot(amount: 60))
    }

    // GIVEN JSON explicitly declaring an unknown caffeine rule,
    // WHEN the rule is decoded,
    // THEN it remains unknown without requiring a numeric value.
    @Test func decodesUnknownRule() throws {
        let json = """
        {"kind": "unknown"}
        """

        let rule = try JSONDecoder().decode(
            CaffeineRule.self,
            from: Data(json.utf8)
        )

        #expect(rule == .unknown)
    }
    
    // GIVEN caffeine rule JSON with missing, unsupported or incorrectly typed fields,
    // WHEN decoding is attempted,
    // THEN decoding fails instead of inventing a rule or numeric default.
    @Test(arguments: [
        """
        {}
        """,
        """
        {"kind": "someFutureRule"}
        """,
        """
        {"kind": 123}
        """,
        """
        {"kind": "perVolume"}
        """,
        """
        {"kind": "perShot"}
        """,
        """
        {"kind": "perVolume", "concentration": "12.5"}
        """,
        """
        {"kind": "perShot", "amount": "60"}
        """,
        """
        {"kind": "perVolume", "concentration": null}
        """,
        """
        {"kind": "perShot", "amount": null}
        """
    ])
    func rejectsInvalidRuleData(json: String) {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                CaffeineRule.self,
                from: Data(json.utf8)
            )
        }
    }
    
    // GIVEN a volume-based caffeine rule,
    // WHEN the rule is encoded,
    // THEN its JSON contains only the expected kind and concentration.
    @Test func encodesPerVolumeRule() throws {
        let rule = CaffeineRule.perVolume(concentration: 12.5)
        let data = try JSONEncoder().encode(rule)
        let object = try JSONSerialization.jsonObject(with: data)
        let json = try #require(object as? [String: Any])

        #expect((json["kind"] as? String) == "perVolume")
        #expect((json["concentration"] as? Double) == 12.5)
        #expect(json.count == 2)
    }

    // GIVEN a shot-based caffeine rule,
    // WHEN the rule is encoded,
    // THEN its JSON contains only the expected kind and amount per shot.
    @Test func encodesPerShotRule() throws {
        let rule = CaffeineRule.perShot(amount: 60)
        let data = try JSONEncoder().encode(rule)
        let object = try JSONSerialization.jsonObject(with: data)
        let json = try #require(object as? [String: Any])

        #expect((json["kind"] as? String) == "perShot")
        #expect((json["amount"] as? Double) == 60)
        #expect(json.count == 2)
    }

    // GIVEN an unknown caffeine rule,
    // WHEN the rule is encoded,
    // THEN its JSON contains only the unknown kind.
    @Test func encodesUnknownRule() throws {
        let rule = CaffeineRule.unknown
        let data = try JSONEncoder().encode(rule)
        let object = try JSONSerialization.jsonObject(with: data)
        let json = try #require(object as? [String: Any])

        #expect((json["kind"] as? String) == "unknown")
        #expect(json.count == 1)
    }
}
