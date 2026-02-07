//
//  DeviceError.swift
//  ToroAlerts
//
//  Errors that can occur during USB Hubcot device operations
//

import Foundation

/// Errors that can occur during Hubcot device operations
public enum DeviceError: Error, CustomStringConvertible, Sendable {
    case deviceNotFound
    case connectionFailed(IOReturn?)
    case deviceNotConnected
    case requestFailed(IOReturn)

    public var description: String {
        switch self {
        case .deviceNotFound:
            return "Hubcot device not found"
        case .connectionFailed(let kr):
            if let kr {
                return "Failed to connect to device (0x\(String(format: "%08x", kr)))"
            }
            return "Failed to connect to device"
        case .deviceNotConnected:
            return "Device not connected"
        case .requestFailed(let kr):
            return "Request failed (0x\(String(format: "%08x", kr)))"
        }
    }
}
