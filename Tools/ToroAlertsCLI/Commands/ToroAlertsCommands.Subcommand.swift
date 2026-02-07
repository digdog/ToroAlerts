//
//  ToroAlertsCommands.Subcommand.swift
//  ToroAlertsCLI
//
//  Base protocol for all subcommands
//

import Foundation
import ArgumentParser

extension Commands {
    /// Protocol that all subcommands must implement
    protocol Subcommand: AsyncParsableCommand {
        var globalOptions: GlobalOptions { get }
        mutating func runSubcommand() async throws
    }
}

// MARK: - Default Implementation

extension Commands.Subcommand {
    /// Default run implementation that calls runSubcommand
    mutating func run() async throws {
        try await runSubcommand()
    }

    /// Execute a block with performance measurement if enabled
    func withMeasurement<ReturnValue>(
        label: StaticString,
        perform body: () async throws -> ReturnValue
    ) async rethrows -> ReturnValue {
        if globalOptions.shouldMeasure {
            let clock = ContinuousClock()
            let start = clock.now
            let returnValue = try await body()
            let duration = clock.now - start
            print("\(label): \(duration)")
            return returnValue
        } else {
            return try await body()
        }
    }

    /// Log a message if verbose mode is enabled
    func log(_ message: String) {
        if globalOptions.verbose {
            print(message)
        }
    }
}
