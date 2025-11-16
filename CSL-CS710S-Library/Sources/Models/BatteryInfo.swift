import Foundation

/// Battery status information
public struct BatteryInfo {
    public let level: Int           // Battery level (0-100%)
    public let isCharging: Bool     // Is device charging
    public let timestamp: TimeInterval

    public init(level: Int, isCharging: Bool = false, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.level = level
        self.isCharging = isCharging
        self.timestamp = timestamp
    }

    /// Check if battery level is valid
    public var isValid: Bool {
        return level >= 0 && level <= 100
    }

    /// Battery level description
    public var levelDescription: String {
        if isCharging {
            return "\(level)% (Charging)"
        }
        return "\(level)%"
    }
}
