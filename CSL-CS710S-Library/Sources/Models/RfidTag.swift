import Foundation

/// Represents an RFID tag read
public struct RfidTag: Identifiable, Equatable {
    public let id: String  // EPC as identifier
    public let epc: String
    public let rssi: Double  // Signal strength in dBm (negative values)
    public let count: Int
    public let phase: Int
    public let channel: Int
    public let timestamp: TimeInterval

    public init(
        epc: String,
        rssi: Double = 0.0,
        count: Int = 1,
        phase: Int = 0,
        channel: Int = 0,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = epc
        self.epc = epc
        self.rssi = rssi
        self.count = count
        self.phase = phase
        self.channel = channel
        self.timestamp = timestamp
    }

    /// Creates a new tag with updated count
    public func withCount(_ newCount: Int) -> RfidTag {
        return RfidTag(
            epc: self.epc,
            rssi: self.rssi,
            count: newCount,
            phase: self.phase,
            channel: self.channel,
            timestamp: self.timestamp
        )
    }

    /// Creates a new tag with updated RSSI and count
    public func withUpdatedRead(rssi: Double, count: Int) -> RfidTag {
        return RfidTag(
            epc: self.epc,
            rssi: rssi,
            count: count,
            phase: self.phase,
            channel: self.channel,
            timestamp: Date().timeIntervalSince1970
        )
    }
}
