//
//  ToroAlertsCLI.swift
//  ToroAlertsCLI
//
//  Command-line interface for controlling USB Hubcot devices
//

import Foundation
import ArgumentParser
import ToroAlerts

@main
struct ToroAlertsCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toroalertsctl",
        abstract: "A utility for controlling USB Hubcot devices",
        discussion: """
        toroalertsctl is a command-line tool for controlling USB Hubcot devices.
        It supports various animation patterns with configurable speed settings.

        The tool will automatically detect and connect to either Toro or Kitty devices.
        """,
        version: Commands.version,
        subcommands: [
            Commands.Send.self,
            Commands.List.self,
            Commands.Info.self,
            Commands.Version.self
        ],
        defaultSubcommand: Commands.Send.self
    )

    @OptionGroup var globalOptions: Commands.GlobalOptions
}

// MARK: - Extended Help

extension ToroAlertsCLI {
    static var _errorLabel: String { "Error" }
}
