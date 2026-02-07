//
//  Info.swift
//  ToroAlertsCLI
//
//  Info command - displays device information
//

import Foundation
import ArgumentParser
import ToroAlerts

extension Commands {
    /// Display information about connected Hubcot devices
    struct Info: Subcommand {
        static let configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Display information about connected Hubcot devices",
            discussion: """
            Shows detailed information about the connected Hubcot device,
            including device type, vendor ID, product ID, and connection status.

            Examples:
              toroalertsctl info
              toroalertsctl info --verbose
              toroalertsctl info --json
            """
        )

        @OptionGroup var globalOptions: GlobalOptions

        @Flag(name: .long, help: "Output in JSON format")
        var json = false

        mutating func runSubcommand() async throws {
            try await withMeasurement(label: "Device Detection Time") {
                // Try to detect device type
                let deviceInfo = await detectDevice()

                if json {
                    try printJSON(deviceInfo)
                } else {
                    printTable(deviceInfo)
                }
            }
        }

        // MARK: - Device Information

        struct DeviceInfo {
            let deviceType: String
            let vendorID: UInt16
            let productID: UInt16
            let isConnected: Bool
        }

        private func detectDevice() async -> DeviceInfo {
            let coordinator = DeviceCoordinator()
            let events = coordinator.newEventStream()
            coordinator.start()

            for await event in events {
                switch event {
                case .connected(let type):
                    coordinator.finish()
                    return DeviceInfo(
                        deviceType: type.rawValue,
                        vendorID: type.vendorID,
                        productID: type.productID,
                        isConnected: true
                    )
                case .disconnected, .sendFailed:
                    coordinator.finish()
                    return DeviceInfo(
                        deviceType: "None",
                        vendorID: 0,
                        productID: 0,
                        isConnected: false
                    )
                }
            }

            return DeviceInfo(
                deviceType: "None",
                vendorID: 0,
                productID: 0,
                isConnected: false
            )
        }

        // MARK: - Output Formatting

        private func printTable(_ info: DeviceInfo) {
            print("Hubcot Device Information:")
            print("")
            print("  Device Type:  \(info.deviceType)")
            print("  Vendor ID:    0x\(String(format: "%04X", info.vendorID)) (\(info.vendorID))")
            print("  Product ID:   0x\(String(format: "%04X", info.productID)) (\(info.productID))")
            print("  Status:       \(info.isConnected ? "✓ Connected" : "✗ Not Connected")")
            print("")

            if !info.isConnected {
                print("No Hubcot device found. Please check:")
                print("  • Device is connected via USB")
                print("  • Device has power")
                print("  • USB cable is working properly")
            }
        }

        private struct DeviceInfoOutput: Codable {
            let deviceType: String
            let vendorID: UInt16
            let vendorIDHex: String
            let productID: UInt16
            let productIDHex: String
            let isConnected: Bool
        }

        private func printJSON(_ info: DeviceInfo) throws {
            let output = DeviceInfoOutput(
                deviceType: info.deviceType,
                vendorID: info.vendorID,
                vendorIDHex: String(format: "0x%04X", info.vendorID),
                productID: info.productID,
                productIDHex: String(format: "0x%04X", info.productID),
                isConnected: info.isConnected
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
