//
//  Version.swift
//  ToroAlertsCLI
//
//  Version command - displays version information
//

import Foundation
import ArgumentParser

extension Commands {
    /// Display version information
    struct Version: Subcommand {
        static let configuration = CommandConfiguration(
            commandName: "version",
            abstract: "Display version information"
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Flag(name: .long, help: "Output in JSON format")
        var json = false

        mutating func runSubcommand() async throws {
            if json {
                try printJSON()
            } else {
                printTable()
            }
        }

        private func printTable() {
            print("toroalertsctl version \(Commands.version)")
            print("Swift-based USB Hubcot device controller")
            print("")
            print("Supported devices:")
            print("  • Toro (VID: 0x054D, PID: 0x1B59)")
            print("  • Kitty (VID: 0x0D74, PID: 0xD001)")
        }

        private struct SupportedDevice: Codable {
            let name: String
            let vendorID: String
            let productID: String
        }

        private struct VersionOutput: Codable {
            let version: String
            let toolName: String
            let description: String
            let supportedDevices: [SupportedDevice]
        }

        private func printJSON() throws {
            let output = VersionOutput(
                version: Commands.version,
                toolName: "toroalertsctl",
                description: "Swift-based USB Hubcot device controller",
                supportedDevices: [
                    SupportedDevice(name: "Toro", vendorID: "0x054D", productID: "0x1B59"),
                    SupportedDevice(name: "Kitty", vendorID: "0x0D74", productID: "0xD001")
                ]
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(output)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}
