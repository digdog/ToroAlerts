//
//  DeviceConstants.swift
//  ToroAlerts
//
//  USB Hubcot device definitions and constants
//

import Foundation
import IOKit
import IOKit.usb

/// USB Vendor and Product IDs for devices
enum DeviceConstants {
    /// Toro device identifiers
    static let toroVendorID: UInt16 = 0x054D
    static let toroProductID: UInt16 = 0x1B59

    /// Kitty device identifiers
    static let kittyVendorID: UInt16 = 0x0D74
    static let kittyProductID: UInt16 = 0xD001
}

/// IOKit UUIDs for USB device communication
/// These are defined as C macros which Swift cannot import directly
nonisolated(unsafe) internal let kIOUSBDeviceUserClientTypeIDValue = CFUUIDGetConstantUUIDWithBytes(nil,
    0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
    0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

nonisolated(unsafe) internal let kIOCFPlugInInterfaceIDValue = CFUUIDGetConstantUUIDWithBytes(nil,
    0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
    0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F)

nonisolated(unsafe) internal let kIOUSBDeviceInterfaceIDValue = CFUUIDGetConstantUUIDWithBytes(nil,
    0x5c, 0x81, 0x87, 0xd0, 0x9e, 0xf3, 0x11, 0xD4,
    0x8b, 0x45, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)
