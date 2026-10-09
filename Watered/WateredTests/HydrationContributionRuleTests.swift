//
//  HydrationContributionRuleTests.swift
//  Watered
//
//  Created by Frank Sedivy on 09/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct HydrationContributionRuleTests {
    
    // GIVEN JSON describing a ratio rule,
    // WHEN the rule is decoded,
    // THEN its ratio value is preserved.
    @Test func decodesRatioRule() throws {
        let json = """
        {
            "kind": "ratio",
            "ratio": 0.75
        }
        """

        let rule = try JSONDecoder().decode(
            HydrationContributionRule.self,
            from: Data(json.utf8)
        )

        #expect(rule == .ratio(0.75))
    }
    
    // GIVEN JSON describing an alcohol rule with a default ABV,
    // WHEN the rule is decoded,
    // THEN its ABV is preserved as a fraction.
    @Test func decodesAlcoholRule() throws {
        let json = """
        {
            "kind": "alcohol",
            "defaultABV": 0.05
        }
        """

        let rule = try JSONDecoder().decode(
            HydrationContributionRule.self,
            from: Data(json.utf8)
        )

        #expect(rule == .alcohol(defaultABV: 0.05))
    }
    
    // GIVEN JSON explicitly declaring an unknown contribution rule,
    // WHEN the rule is decoded,
    // THEN it remains unknown without requiring a numeric value.
    @Test func decodesUnknownRule() throws {
        let json = """
        {
            "kind": "unknown"
        }
        """

        let rule = try JSONDecoder().decode(
            HydrationContributionRule.self,
            from: Data(json.utf8)
        )

        #expect(rule == .unknown)
    }
    
    // GIVEN JSON containing an unsupported rule kind,
    // WHEN decoding is attempted,
    // THEN decoding fails instead of returning an unknown rule.
    @Test func rejectsUnsupportedRuleKind() {
        let json = """
        {
            "kind": "someFutureRule"
        }
        """

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                HydrationContributionRule.self,
                from: Data(json.utf8)
            )
        }
    }
    
    // GIVEN a recognised numeric rule without its required value,
    // WHEN decoding is attempted,
    // THEN decoding fails rather than supplying a default.
    @Test(arguments: ["ratio", "alcohol"])
    func rejectsMissingRuleValue(kind: String) {
        let json = """
        {
            "kind": "\(kind)"
        }
        """

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                HydrationContributionRule.self,
                from: Data(json.utf8)
            )
        }
    }
    
    // GIVEN a numeric rule containing a string or null instead of a number,
    // WHEN decoding is attempted,
    // THEN decoding rejects the incorrectly typed value.
    @Test(arguments: [
        """
        {"kind": "ratio", "ratio": "0.75"}
        """,
        """
        {"kind": "ratio", "ratio": null}
        """,
        """
        {"kind": "alcohol", "defaultABV": "0.05"}
        """,
        """
        {"kind": "alcohol", "defaultABV": null}
        """
    ])
    func rejectsIncorrectlyTypedRuleValue(json: String) {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                HydrationContributionRule.self,
                from: Data(json.utf8)
            )
        }
    }
}
