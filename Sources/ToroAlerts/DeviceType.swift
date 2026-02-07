//
//  DeviceType.swift
//  ToroAlerts
//
//  USB Hubcot Device type identification
//

/// Device type
public enum DeviceType: String, Sendable, Codable, CaseIterable {
    case toro = "Toro"
    case kitty = "Kitty"

    /// Vendor ID for this device type
    public var vendorID: UInt16 {
        switch self {
        case .toro: return DeviceConstants.toroVendorID
        case .kitty: return DeviceConstants.kittyVendorID
        }
    }

    /// Product ID for this device type
    public var productID: UInt16 {
        switch self {
        case .toro: return DeviceConstants.toroProductID
        case .kitty: return DeviceConstants.kittyProductID
        }
    }
}
