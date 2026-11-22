//
//  DrinkEntrySource.swift
//  Watered
//
//  Created by Frank Sedivy on 05/09/2026.
//

import Foundation

// MARK: - DrinK Entry Source
//
// Purpose:
// Describes where a drink entry came from
//
// Persistence role:
// Stores a small source value that can later help Watered distinguish manual
// entries from healthKit or imported entries.
nonisolated enum DrinkEntrySource: String, Codable {
    case manual
}
