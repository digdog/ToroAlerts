//
//  Send.swift
//  ToroAlertsCLI
//
//  Send command - sends a request to the Hubcot device
//

import Foundation
import ArgumentParser
import ToroAlerts

extension Commands {
    /// Send a request to the Hubcot device
    struct Send: Subcommand {
        static let configuration = CommandConfiguration(
            commandName: "send",
            abstract: "Send a request to the Hubcot device",
            discussion: """
            Sends a control request to the connected Hubcot device with the specified
            animation pattern and delay. The request can be specified as a decimal number
            (0-255) or hexadecimal (0xNN).

            Examples:
              toroalertsctl send --request 0x03 --delay 100
              toroalertsctl send -r 3 -d 100
            """
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Option(name: [.short, .long], help: "Request type (0-255 or hex 0xNN)")
        var request: String

        @Option(name: [.short, .long], help: "Delay in milliseconds (0=fast, higher=slower)")
        var delay: UInt16

        mutating func runSubcommand() async throws {
            // Parse request value (decimal or hex)
            guard let requestValue = parseRequestValue(request) else {
                throw ValidationError("Invalid request value: '\(request)'. Use decimal (0-255) or hex (0xNN) format.")
            }

            // Log request information if verbose
            if globalOptions.verbose {
                print("Request Type: 0x\(String(format: "%02X", requestValue)) (\(requestValue))")
                if let knownRequest = DeviceRequest(rawValue: requestValue) {
                    print("Description: \(knownRequest.description)")
                } else {
                    print("Description: Unknown/Custom request type")
                }
                print("Delay: \(delay) milliseconds")
                print("")
            }

            let interval = Duration.milliseconds(Int64(delay))

            // Connect to device and send request via coordinator
            try await withMeasurement(label: "Total Execution Time") {
                let coordinator = DeviceCoordinator()
                let events = coordinator.newEventStream()

                try await withMeasurement(label: "Device Connection & Send Time") {
                    log("Searching for Hubcot device...")
                    coordinator.start()

                    // Wait for connection, then send
                    for await event in events {
                        switch event {
                        case .connected(let deviceType):
                            log("Connected to \(deviceType.rawValue) device")
                            coordinator.yield(rawValue: requestValue, interval: interval)
                            log("Request sent successfully")
                            await coordinator.finishAndWait()
                            return

                        case .sendFailed(let error):
                            coordinator.finish()
                            throw error

                        case .disconnected:
                            coordinator.finish()
                            throw DeviceError.deviceNotFound
                        }
                    }
                }
            }
        }

        // MARK: - Helper Methods

        private func parseRequestValue(_ string: String) -> UInt8? {
            // Support both decimal and hexadecimal
            if string.hasPrefix("0x") || string.hasPrefix("0X") {
                let hex = String(string.dropFirst(2))
                return UInt8(hex, radix: 16)
            } else {
                return UInt8(string)
            }
        }
    }
}
