//
//  ToroAlertsTests.swift
//  ToroAlertsTests
//
//  Unit tests for ToroAlerts library
//

import Testing
import Foundation
@testable import ToroAlerts

@Suite("DeviceRequest Tests")
struct DeviceRequestTests {

    @Test("All cases have correct raw values, names, descriptions, and round-trip from rawValue")
    func testAllCases() {
        let expected: [(DeviceRequest, UInt8)] = [
            (.noop, 0x00), (.right, 0x01), (.left, 0x02), (.both, 0x03),
            (.bothQuad, 0x04), (.lrlrlr, 0x05), (.rightTriple, 0x06),
            (.bothTriple, 0x08), (.rl, 0x0B), (.rlrlrl, 0x0C),
        ]

        #expect(DeviceRequest.allCases.count == expected.count)

        for (request, rawValue) in expected {
            #expect(request.rawValue == rawValue)
            #expect(!request.name.isEmpty)
            #expect(!request.description.isEmpty)
            #expect(request.description.contains(request.name))
            #expect(DeviceRequest(rawValue: rawValue) == request)
        }

        #expect(DeviceRequest(rawValue: 0xFF) == nil)
    }
}

@Suite("DeviceType Tests")
struct DeviceTypeTests {

    @Test("Device types have correct IDs, raw values, and are Codable")
    func testAllDeviceTypes() throws {
        #expect(DeviceType.allCases.count == 2)

        #expect(DeviceType.toro.vendorID == 0x054D)
        #expect(DeviceType.toro.productID == 0x1B59)
        #expect(DeviceType.toro.rawValue == "Toro")

        #expect(DeviceType.kitty.vendorID == 0x0D74)
        #expect(DeviceType.kitty.productID == 0xD001)
        #expect(DeviceType.kitty.rawValue == "Kitty")

        // Codable round-trip
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for type in DeviceType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(DeviceType.self, from: data)
            #expect(decoded == type)
        }
    }
}

@Suite("DeviceError Tests")
struct DeviceErrorTests {

    @Test("All error variants have correct descriptions")
    func testErrorDescriptions() {
        #expect(DeviceError.deviceNotFound.description.contains("not found"))
        #expect(DeviceError.deviceNotConnected.description.contains("not connected"))
        #expect(DeviceError.connectionFailed(nil).description.contains("Failed to connect"))
        #expect(DeviceError.connectionFailed(0x1234).description.contains("00001234"))
        #expect(DeviceError.requestFailed(0xABCD).description.contains("0000abcd"))
    }
}

@Suite("DeviceCoordinator Tests")
struct DeviceCoordinatorTests {

    @Test("Event streams, fan-out, yield before start, and finish idempotency")
    func testLifecycle() async {
        let coordinator = DeviceCoordinator()

        // Yield before start is a no-op
        coordinator.yield(.left)
        coordinator.yield(rawValue: 0xFF, interval: .milliseconds(50))

        #if DEBUG
        #expect(coordinator.test_eventContinuationCount == 0)
        #endif

        // Fan-out: multiple event streams
        let stream1 = coordinator.newEventStream()
        let stream2 = coordinator.newEventStream()
        let stream3 = coordinator.newEventStream()
        #if DEBUG
        #expect(coordinator.test_eventContinuationCount == 3)
        #endif
        _ = (stream1, stream2, stream3)

        // finish and finishAndWait are safe without start
        coordinator.finish()
        coordinator.finish()
        await coordinator.finishAndWait()
    }
}

@Suite("DeviceCoordinator Integration Tests", .serialized)
struct DeviceCoordinatorIntegrationTests {

    @Test("Coordinator connects and sends", .enabled(if: shouldRunIntegrationTests()))
    func testConnectAndSend() async throws {
        let coordinator = DeviceCoordinator()
        let events = coordinator.newEventStream()
        coordinator.start()

        for await event in events {
            switch event {
            case .connected(let type):
                #expect(type == .toro || type == .kitty)
                coordinator.yield(.lrlrlr, interval: .milliseconds(100))
                await coordinator.finishAndWait()
                return
            case .disconnected:
                Issue.record("Unexpected disconnection")
                coordinator.finish()
                return
            case .sendFailed(let error):
                Issue.record("Send failed: \(error)")
                coordinator.finish()
                return
            }
        }
    }

    private static func shouldRunIntegrationTests() -> Bool {
        return ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "1"
    }
}
