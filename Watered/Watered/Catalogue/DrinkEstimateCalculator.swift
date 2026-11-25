//
//  DrinkEstimateCalculator.swift
//  Watered
//
//  Created by Frank Sedivy on 24/10/2026.
//

import Foundation

/// Resolves catalogue rules into estimates when a drink is logged.
nonisolated enum DrinkEstimateCalculator {
    enum CalculationError: Error {
        case invalidWaterContent
        case invalidAmount
        case invalidHydrationRule
        case nonFiniteResult
        case invalidCaffeineRule
        case invalidShotCount
    }
    
    /// Resolves water content from physical volume, independently of hydration credit.
    ///
    /// Alcohol options use an exact ABV lookup or the configured non-alcoholic fraction;
    /// water content is never inferred from ABV. Other content rules ignore alcohol choices.
    ///
    /// - Parameters:
    ///   - amount: The consumed liquid amount; converted millilitres must be positive and finite,
    ///     even when water content is unknown.
    ///   - content: The water-content rule, with any resolved fraction finite and within 0...1.
    ///   - alcoholABV: The exact ABV fraction to match for alcoholic options; no default is selected here.
    ///   - isNonAlcoholic: Selects the non-alcoholic option, which requires nil `alcoholABV`.
    /// - Returns: Estimated water in millilitres, or nil for unknown content. A zero fraction returns zero.
    /// - Throws: A calculation error for invalid volume or fraction, a missing or contradictory
    ///   alcohol option, or a non-finite result.
    static func waterAmount(for amount: DrinkAmount, content: WaterContent, alcoholABV: Double? = nil, isNonAlcoholic: Bool = false) throws -> Double? {
        let volume = VolumeCalculation.baseValue(from: amount.volume)
        guard volume.isFinite, volume > 0 else { throw CalculationError.invalidAmount }
        switch content {
        case .unknown:
            return nil
        case .alcoholOptions(let options, let nonAlcoholic):
            let fraction = isNonAlcoholic ? nonAlcoholic : options.first(where: { $0.abv == alcoholABV })?.fraction
            guard let fraction, !(isNonAlcoholic && alcoholABV != nil) else {
                throw CalculationError.invalidWaterContent
            }
            return try waterAmount(for: amount, content: .fraction(fraction))
        case .fraction(let value):
            guard value.isFinite, (0...1).contains(value) else {
                throw CalculationError.invalidWaterContent
            }
            let water = volume * value
            guard water.isFinite else { throw CalculationError.nonFiniteResult }
            return water
        }
    }

    /// Calculates hydration contribution using the supplied rule.
    ///
    /// Uses millilitres regardless of the drink's original or displayed unit. The `.alcohol`
    /// rule gives zero goal credit after validating its ABV; other rules resolve independently.
    /// This calculation does not read or update saved snapshots.
    ///
    /// - Parameters:
    ///   - amount: The consumed liquid amount; converted millilitres must be positive and finite,
    ///     even for an unknown rule.
    ///   - rule: The catalogue contribution rule to apply.
    /// - Returns: Estimated contribution in millilitres, or nil for an unknown rule, distinct from zero.
    /// - Throws: A calculation error for invalid inputs or a non-finite result.
    static func hydrationContribution(
        for amount: DrinkAmount,
        rule: HydrationContributionRule
    ) throws -> Double? {
        let volume = VolumeCalculation.baseValue(from: amount.volume)
        
        guard volume.isFinite && volume > 0 else {
            throw CalculationError.invalidAmount
        }
        
        let contribution: Double
        
        switch rule {
        case .ratio(let ratio):
            guard ratio.isFinite && ratio >= 0 else {
                throw CalculationError.invalidHydrationRule
            }
            contribution = volume * ratio
        case .alcohol(let defaultABV):
            guard defaultABV.isFinite && (0...1).contains(defaultABV) else {
                throw CalculationError.invalidHydrationRule
            }
            contribution = 0
            
        case .unknown:
            return nil
        }
        
        guard contribution.isFinite else {
            throw CalculationError.nonFiniteResult
        }
        
        return contribution
    }
    
    /// Calculates caffeine from a prepared volume or selected shot count.
    ///
    /// - Parameters:
    ///   - amount: The consumed liquid amount; converted millilitres must be positive and finite,
    ///     including for per-shot and unknown rules.
    ///   - rule: Caffeine in milligrams per 100 millilitres or per shot, or an unknown estimate.
    ///   - shotCount: The nonnegative count required by a per-shot rule; zero yields known-zero
    ///     caffeine for a valid rule. Ignored by other rules.
    /// - Returns: Estimated caffeine in milligrams, or nil for an unknown rule.
    /// - Throws: A calculation error for invalid inputs or a non-finite result.
    static func caffeineAmount(
        for amount: DrinkAmount,
        rule: CaffeineRule,
        shotCount: Int? = nil
    ) throws -> Double? {
        let volume = VolumeCalculation.baseValue(from: amount.volume)
        
        guard volume.isFinite && volume > 0 else {
            throw CalculationError.invalidAmount
        }
        
        let caffeine: Double
        
        switch rule {
        case .perVolume(let concentration):
            guard concentration.isFinite && concentration >= 0 else {
                throw CalculationError.invalidCaffeineRule
            }
            caffeine = (volume / 100) * concentration
        case .perShot(let perShotAmount):
            guard perShotAmount.isFinite && perShotAmount >= 0 else {
                throw CalculationError.invalidCaffeineRule
            }
            guard let shotCount = shotCount, shotCount >= 0 else {
                throw CalculationError.invalidShotCount
            }
            caffeine = perShotAmount * Double(shotCount)
            
        case .unknown:
            return nil
        }
        
        guard caffeine.isFinite else {
            throw CalculationError.nonFiniteResult
        }
        
        return caffeine
    }
}
