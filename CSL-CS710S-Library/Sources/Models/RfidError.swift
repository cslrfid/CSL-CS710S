import Foundation

/// Error types for RFID operations
public enum RfidErrorType: String, CaseIterable {
    case CONNECTION_FAILED = "CONNECTION_FAILED"
    case CONNECTION_LOST = "CONNECTION_LOST"
    case DISCONNECTED = "DISCONNECTED"
    case NOT_CONNECTED = "NOT_CONNECTED"
    case SCAN_FAILED = "SCAN_FAILED"
    case INVENTORY_FAILED = "INVENTORY_FAILED"
    case CONFIGURATION_FAILED = "CONFIGURATION_FAILED"
    case PERMISSION_DENIED = "PERMISSION_DENIED"
    case BLUETOOTH_DISABLED = "BLUETOOTH_DISABLED"
    case TIMEOUT = "TIMEOUT"
    case UNKNOWN = "UNKNOWN"
}

/// RFID error information
public struct RfidError: Error, CustomStringConvertible {
    public let message: String
    public let type: RfidErrorType
    public let underlyingError: Error?

    public init(message: String, type: RfidErrorType = .UNKNOWN, underlyingError: Error? = nil) {
        self.message = message
        self.type = type
        self.underlyingError = underlyingError
    }

    public var description: String {
        return "RfidError(\(type)): \(message)"
    }

    public var localizedDescription: String {
        return message
    }
}
