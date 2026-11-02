//
//  DrinkEstimateCalculatorTests.swift
//  Watered
//
//  Created by Frank Sedivy on 24/10/2026.
//

import Foundation
import Testing
@testable import Watered

@MainActor
struct DrinkEstimateCalculatorTests {
    // GIVEN a 250 ml drink with a contribution ratio of 0.906,
    // WHEN its hydration contribution is calculated,
    // THEN the result is 226.5 ml.
    @Test func hydrationContributionAppliesCatalogueRatio() throws {
        let amount = DrinkAmount(
            value: 250,
            unit: .milliliters
        )

        let contribution = try DrinkEstimateCalculator.hydrationContribution(
            for: amount,
            rule: .ratio(0.906)
        )

        let result = try #require(contribution)

        #expect(abs(result - 226.5) < 0.000001)
    }
    
    // GIVEN a drink whose hydration contribution rule is unknown,
    // WHEN its contribution is calculated,
    // THEN the result remains nil rather than becoming zero.
    @Test func unknownHydrationContributionRemainsUnknown() throws {
        let amount = DrinkAmount(
            value: 330,
            unit: .milliliters
        )

        let contribution = try DrinkEstimateCalculator.hydrationContribution(
            for: amount,
            rule: .unknown
        )

        #expect(contribution == nil)
    }

    // GIVEN a 200 ml drink with 13% ABV,
    // WHEN the existing alcohol contribution rule is applied,
    // THEN its estimated contribution is -60 ml.
    @Test func alcoholRulePreservesNegativeContribution() throws {
        let amount = DrinkAmount(
            value: 200,
            unit: .milliliters
        )

        let contribution = try DrinkEstimateCalculator.hydrationContribution(
            for: amount,
            rule: .alcohol(defaultABV: 0.13)
        )

        let result = try #require(contribution)

        #expect(abs(result - (-60)) < 0.000001)
    }
    
    // GIVEN one US fluid ounce with a full contribution ratio,
    // WHEN its hydration contribution is calculated,
    // THEN the result is approximately 29.5735 ml.
    @Test func hydrationContributionConvertsToBaseUnit() throws {
        let amount = DrinkAmount(
            value: 1,
            unit: .usFluidOunces
        )

        let contribution = try DrinkEstimateCalculator.hydrationContribution(
            for: amount,
            rule: .ratio(1)
        )

        let result = try #require(contribution)

        #expect(abs(result - 29.5735) < 0.0001)
    }

    // GIVEN a zero, negative or non-finite drink amount,
    // WHEN its hydration contribution is calculated,
    // THEN the calculation throws an error.
    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity])
    func hydrationContributionRejectsInvalidAmounts(value: Double) {
        let amount = DrinkAmount(
            value: value,
            unit: .milliliters
        )

        #expect(throws: DrinkEstimateCalculator.CalculationError.self) {
            _ = try DrinkEstimateCalculator.hydrationContribution(
                for: amount,
                rule: .ratio(1)
            )
        }
    }
    
    // GIVEN a 250 ml drink containing 32 mg of caffeine per 100 ml,
    // WHEN its caffeine amount is calculated,
    // THEN the result is 80 mg.
    @Test func caffeineAmountUsesVolumeConcentration() throws {
        let amount = DrinkAmount(
            value: 250,
            unit: .milliliters
        )

        let caffeine = try DrinkEstimateCalculator.caffeineAmount(
            for: amount,
            rule: .perVolume(concentration: 32)
        )

        let result = try #require(caffeine)

        #expect(result == 80)
    }

    // GIVEN two shots containing 60 mg of caffeine each,
    // WHEN caffeine is calculated for different finished drink volumes,
    // THEN the result remains 120 mg.
    @Test(arguments: [200.0, 350.0])
    func shotBasedCaffeineDoesNotChangeWithCupSize(volumeValue: Double) throws {
        let amount = DrinkAmount(
            value: volumeValue,
            unit: .milliliters
        )

        let caffeine = try DrinkEstimateCalculator.caffeineAmount(
            for: amount,
            rule: .perShot(amount: 60),
            shotCount: 2
        )

        let result = try #require(caffeine)

        #expect(result == 120)
    }
    
    // GIVEN unknown caffeine and an explicitly caffeine-free preparation,
    // WHEN their caffeine amounts are calculated,
    // THEN unknown remains nil while the known caffeine-free amount is zero.
    @Test func caffeineDistinguishesUnknownFromZero() throws {
        let amount = DrinkAmount(
            value: 250,
            unit: .milliliters
        )

        let unknown = try DrinkEstimateCalculator.caffeineAmount(
            for: amount,
            rule: .unknown
        )

        let zero = try DrinkEstimateCalculator.caffeineAmount(
            for: amount,
            rule: .perVolume(concentration: 0)
        )

        #expect(unknown == nil)
        #expect(zero == 0)
    }

    // GIVEN a per-shot caffeine rule without a selected shot count,
    // WHEN its caffeine amount is calculated,
    // THEN the calculation throws an error.
    @Test func shotBasedCaffeineRequiresShotCount() {
        let amount = DrinkAmount(
            value: 250,
            unit: .milliliters
        )

        #expect(throws: DrinkEstimateCalculator.CalculationError.self) {
            _ = try DrinkEstimateCalculator.caffeineAmount(
                for: amount,
                rule: .perShot(amount: 60)
            )
        }
    }
}
