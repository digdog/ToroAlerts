//
//  ToroAlertsCommands.GlobalOptions.swift
//  ToroAlertsCLI
//
//  Global options available to all commands
//

import Foundation
import ArgumentParser

extension Commands {
    /// Global options available to all commands
    struct GlobalOptions: ParsableArguments {
        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose = false

        @Flag(name: .customLong("measure"), help: "Measure and display execution time")
        var shouldMeasure = false
    }
}
