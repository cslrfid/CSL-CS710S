import Foundation

/// Reader configuration settings
public struct RfidConfiguration {
    /// Power level in 0.1 dBm units (0-320 = 0.0-32.0 dBm)
    public var powerLevel: Int
    /// Inventory session (0-3)
    public var session: Int
    /// Target flag
    public var target: RfidTarget
    /// Inventory mode
    public var inventoryMode: RfidInventoryMode
    /// Frequency region
    public var region: RfidRegion
    /// Q value for inventory algorithm (0-15)
    public var qValue: Int
    /// Enable beep on tag read
    public var enableBeep: Bool
    /// Enable vibration on tag read
    public var enableVibrate: Bool

    /// Default configuration
    public static let `default` = RfidConfiguration(
        powerLevel: 300,           // 30.0 dBm
        session: 0,
        target: .A,
        inventoryMode: .COMPACT,
        region: .FCC,
        qValue: 7,
        enableBeep: true,
        enableVibrate: true
    )

    public init(
        powerLevel: Int = 300,
        session: Int = 0,
        target: RfidTarget = .A,
        inventoryMode: RfidInventoryMode = .COMPACT,
        region: RfidRegion = .FCC,
        qValue: Int = 7,
        enableBeep: Bool = true,
        enableVibrate: Bool = true
    ) {
        self.powerLevel = powerLevel
        self.session = session
        self.target = target
        self.inventoryMode = inventoryMode
        self.region = region
        self.qValue = qValue
        self.enableBeep = enableBeep
        self.enableVibrate = enableVibrate
    }

    /// Power level in dBm
    public var powerLevelInDbm: Double {
        return Double(powerLevel) / 10.0
    }
}
