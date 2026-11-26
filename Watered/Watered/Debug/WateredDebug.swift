//
//  WateredDebug.swift
//  Watered
//
//  Created by Frank Sedivy on 01/07/2026.
//

import Foundation

#if DEBUG
import OSLog

private let wateredDebugLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.franksedivy.watered-ios",
    category: "debug"
)
#endif

/// Writes a public message to the local unified log in Debug; Release discards it.
/// Callers must supply non-personal diagnostics because the message is not redacted.
func wateredLog(_ message: String) {
    #if DEBUG
    wateredDebugLogger.debug("\(message, privacy: .public)")
    #endif
}
