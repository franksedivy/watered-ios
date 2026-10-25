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
        case invalidAmount
        case invalidHydrationRule
        case nonFiniteResult
        case invalidCaffeineRule
        case invalidShotCount
    }
    
    /// Calculates hydration contribution using the supplied rule
    ///
    /// uses millilitres regardless of the drink's original or displayed unit. The alcohol calculation preserves Watered's
    /// existing heuristic.
    ///
    /// - Parameters:
    ///   - amount: The consumed liquid amount, which must be positive and finite.
    ///   - rule: The catalogue contribution rule to apply.
    /// - Returns: Estimated contribution in milliliteres, or nil for an uknown rule
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
            let alcohoVolume = volume * defaultABV
            contribution = volume - (alcohoVolume * 10)
            
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
    ///   - amount: The consumed liquid amount, which mus tbe positive and finite
    ///   - rule: The caffeine rule to apply.
    ///   - shotCount: The positive shot count required by a per-shot rule.
    /// - Returns: Estimated caffeine in milligrams, or nil for an unknown rule.
    /// - Throws: A claculation error for invalid inputs or a non-finite result.
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
            guard let shotCount = shotCount, shotCount > 0 else {
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
