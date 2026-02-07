//
//  DeviceRequest.swift
//  ToroAlerts
//
//  USB Hubcot device request types (commands)
//

import Foundation

/// Hubcot device request types
public enum DeviceRequest: UInt8, CaseIterable, CustomStringConvertible, Sendable {
    case noop        = 0x00  // No operation
    case right       = 0x01  // Move right
    case left        = 0x02  // Move left
    case both        = 0x03  // Both sides
    case bothQuad    = 0x04  // Both sides x4
    case lrlrlr      = 0x05  // Left-Right pattern
    case rightTriple = 0x06  // Right x3
    case bothTriple  = 0x08  // Both sides x3
    case rl          = 0x0B  // Right-Left
    case rlrlrl      = 0x0C  // Right-Left pattern
    
    /// Human-readable description of the request
    public var description: String {
        switch self {
        case .noop:        return "NOOP (No operation)"
        case .right:       return "RIGHT (Move right)"
        case .left:        return "LEFT (Move left)"
        case .both:        return "BOTH (Both sides)"
        case .bothQuad:    return "BOTH_QUAD (Both sides x4)"
        case .lrlrlr:      return "LRLRLR (Left-Right pattern)"
        case .rightTriple: return "RIGHT_TRIPLE (Right x3)"
        case .bothTriple:  return "BOTH_TRIPLE (Both sides x3)"
        case .rl:          return "RL (Right-Left)"
        case .rlrlrl:      return "RLRLRL (Right-Left pattern)"
        }
    }
    
    /// Short name for the request
    public var name: String {
        switch self {
        case .noop:        return "NOOP"
        case .right:       return "RIGHT"
        case .left:        return "LEFT"
        case .both:        return "BOTH"
        case .bothQuad:    return "BOTH_QUAD"
        case .lrlrlr:      return "LRLRLR"
        case .rightTriple: return "RIGHT_TRIPLE"
        case .bothTriple:  return "BOTH_TRIPLE"
        case .rl:          return "RL"
        case .rlrlrl:      return "RLRLRL"
        }
    }
}
