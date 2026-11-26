//
//  DrinkEntrySource.swift
//  Watered
//
//  Created by Frank Sedivy on 05/09/2026.
//

import Foundation

// MARK: - Drink Entry Source
/// Records a drink entry’s origin using a persisted raw value.
/// Only manual entry is currently supported.
nonisolated enum DrinkEntrySource: String, Codable {
    case manual
}
