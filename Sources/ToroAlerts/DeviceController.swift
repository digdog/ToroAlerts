//
//  DeviceController.swift
//  ToroAlerts
//
//  Swift version of USB Hubcot device controller using IOKit
//  Inspired from the hubcot_linux driver by Tomoaki MITSUYOSHI
//

import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os
import Synchronization

// MARK: - Controller

/// Mutable state protected by Mutex
private struct DeviceState: @unchecked Sendable {
    var deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?
    var usbDevice: io_service_t
}

/// Controller for managing Hubcot USB devices
final class DeviceController: Sendable {

    // MARK: - Properties

    private static let logger = Logger(subsystem: "ToroAlerts", category: "DeviceController")

    private let state: Mutex<DeviceState>

    /// The type of connected device
    let deviceType: DeviceType

    /// Whether the device is currently connected
    var isConnected: Bool {
        state.withLock { $0.deviceInterface != nil && $0.usbDevice != 0 }
    }

    // MARK: - Initialization

    private init(
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?,
        usbDevice: io_service_t,
        deviceType: DeviceType
    ) {
        self.state = Mutex(DeviceState(deviceInterface: deviceInterface, usbDevice: usbDevice))
        self.deviceType = deviceType
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection

    /// Finds and connects to a Hubcot device
    /// - Parameter deviceType: Specific device type to connect to, or `nil` for auto-detection
    /// - Returns: A connected DeviceController
    static func connect(deviceType: DeviceType? = nil) throws -> DeviceController {
        logger.debug("Searching for Hubcot device...")

        if let deviceType {
            let device = try findDevice(vendorID: deviceType.vendorID, productID: deviceType.productID)
            logger.debug("Found \(deviceType.rawValue, privacy: .public) device")
            return try connectToDevice(device, deviceType: deviceType)
        }

        // Auto-detect: try each device type
        for type in DeviceType.allCases {
            if let device = try? findDevice(vendorID: type.vendorID, productID: type.productID) {
                logger.debug("Found \(type.rawValue, privacy: .public) device")
                return try connectToDevice(device, deviceType: type)
            }
        }

        throw DeviceError.deviceNotFound
    }

    /// Disconnects from the device and releases resources
    func disconnect() {
        state.withLock { state in
            if let devInterface = state.deviceInterface {
                _ = devInterface.pointee?.pointee.USBDeviceClose(devInterface)
                _ = devInterface.pointee?.pointee.Release(devInterface)
                state.deviceInterface = nil
            }

            if state.usbDevice != 0 {
                IOObjectRelease(state.usbDevice)
                state.usbDevice = 0
            }
        }

        Self.logger.debug("Hubcot device disconnected")
    }

    // MARK: - Sending Requests

    /// Sends a predefined request to the Hubcot device
    /// - Parameters:
    ///   - request: The request type to send
    ///   - interval: Delay between movements (`.zero` = fastest)
    func send(_ request: DeviceRequest, interval: Duration = .milliseconds(100)) throws {
        try send(rawValue: request.rawValue, interval: interval)
        Self.logger.debug("Sent request: \(request.description, privacy: .public) with interval: \(String(describing: interval), privacy: .public)")
    }

    /// Sends a raw request value to the Hubcot device
    /// - Parameters:
    ///   - rawValue: The raw request value (0-255)
    ///   - interval: Delay between movements (`.zero` = fastest)
    func send(rawValue: UInt8, interval: Duration = .milliseconds(100)) throws {
        try state.withLock { state in
            guard let devInterface = state.deviceInterface, state.usbDevice != 0 else {
                throw DeviceError.deviceNotConnected
            }

            try Self.performControlTransfer(devInterface: devInterface, requestValue: rawValue, interval: interval)
        }
        Self.logger.debug("Sent raw request: 0x\(String(format: "%02X", rawValue), privacy: .public) with interval: \(String(describing: interval), privacy: .public)")
    }

    // MARK: - Private

    private static func performControlTransfer(
        devInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>,
        requestValue: UInt8,
        interval: Duration
    ) throws {
        let ms = UInt16(clamping: max(0, Int64(interval / .milliseconds(1))))

        var deviceRequest = IOUSBDevRequest()
        deviceRequest.bmRequestType = UInt8((kUSBOut << kUSBRqDirnShift) | (kUSBVendor << kUSBRqTypeShift) | kUSBDevice)
        deviceRequest.bRequest = requestValue
        deviceRequest.wValue = ms
        deviceRequest.wIndex = 0
        deviceRequest.wLength = 0
        deviceRequest.pData = nil

        let kr = devInterface.pointee?.pointee.DeviceRequest(devInterface, &deviceRequest)

        guard kr == kIOReturnSuccess else {
            throw DeviceError.requestFailed(kr ?? 0)
        }
    }

    private static func findDevice(vendorID: UInt16, productID: UInt16) throws -> io_service_t {
        guard let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary? else {
            throw DeviceError.connectionFailed(nil)
        }

        matchingDict[kUSBVendorID] = NSNumber(value: vendorID)
        matchingDict[kUSBProductID] = NSNumber(value: productID)

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        guard kr == KERN_SUCCESS else {
            throw DeviceError.connectionFailed(kr)
        }

        defer { IOObjectRelease(iterator) }

        let device = IOIteratorNext(iterator)
        guard device != 0 else {
            throw DeviceError.deviceNotFound
        }

        return device
    }

    private static func connectToDevice(_ usbDevice: io_service_t, deviceType: DeviceType) throws -> DeviceController {
        var plugInInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0

        let kr = IOCreatePlugInInterfaceForService(
            usbDevice,
            kIOUSBDeviceUserClientTypeIDValue,
            kIOCFPlugInInterfaceIDValue,
            &plugInInterface,
            &score
        )

        guard kr == kIOReturnSuccess, let plugIn = plugInInterface else {
            IOObjectRelease(usbDevice)
            throw DeviceError.connectionFailed(kr)
        }

        defer {
            _ = plugIn.pointee?.pointee.Release(plugIn)
        }

        var deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?
        let uuid = CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceIDValue!)

        let result = withUnsafeMutablePointer(to: &deviceInterface) { devicePtr in
            plugIn.pointee?.pointee.QueryInterface(
                plugIn,
                uuid,
                UnsafeMutablePointer(OpaquePointer(devicePtr))
            )
        }

        guard result == S_OK, let devInterface = deviceInterface else {
            IOObjectRelease(usbDevice)
            throw DeviceError.connectionFailed(nil)
        }

        let openResult = devInterface.pointee?.pointee.USBDeviceOpen(devInterface)
        guard openResult == kIOReturnSuccess else {
            _ = devInterface.pointee?.pointee.Release(devInterface)
            IOObjectRelease(usbDevice)
            throw DeviceError.connectionFailed(openResult ?? 0)
        }

        logger.debug("Hubcot device connected successfully")

        return DeviceController(
            deviceInterface: devInterface,
            usbDevice: usbDevice,
            deviceType: deviceType
        )
    }
}
