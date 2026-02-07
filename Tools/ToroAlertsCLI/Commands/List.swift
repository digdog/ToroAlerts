//
//  List.swift
//  ToroAlertsCLI
//
//  List command - lists all available request types
//

import Foundation
import ArgumentParser
import ToroAlerts

extension Commands {
    /// List all available request types
    struct List: Subcommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all available request types",
            discussion: """
            Displays all predefined request types supported by Hubcot devices,
            including their hexadecimal and decimal values, and descriptions.

            You can also use custom request types (0x00-0xFF / 0-255) that are
            not in the predefined list.

            Examples:
              toroalertsctl list
              toroalertsctl list --verbose
            """
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

        // MARK: - Output Formatting

        private func printTable() {
            print("Available Request Types:")
            print("")

            for request in DeviceRequest.allCases {
                let hex = String(format: "0x%02X", request.rawValue)
                let dec = String(format: "%2d", request.rawValue)
                print("  \(hex) (\(dec))  -  \(request.description)")
            }

            print("")
            print("You can also use custom request types (0x00-0xFF / 0-255)")
        }

        // MARK: - Codable Output

        private struct RequestOutput: Codable {
            let rawValue: UInt8
            let hexValue: String
            let name: String
            let description: String
        }

        private struct ListOutput: Codable {
            let requests: [RequestOutput]
            let customRange: CustomRange

            struct CustomRange: Codable {
                let min: Int
                let max: Int
                let description: String
            }
        }

        private func printJSON() throws {
            let output = ListOutput(
                requests: DeviceRequest.allCases.map { request in
                    RequestOutput(
                        rawValue: request.rawValue,
                        hexValue: String(format: "0x%02X", request.rawValue),
                        name: request.name,
                        description: request.description
                    )
                },
                customRange: ListOutput.CustomRange(
                    min: 0,
                    max: 255,
                    description: "Custom request types can use any value in this range"
                )
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
