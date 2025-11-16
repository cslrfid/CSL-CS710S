import Foundation

/// Geiger search statistics
public struct RfidGeigerStats {
    public let targetEpc: String
    public let currentRssi: Double  // Current RSSI in dBm (negative)
    public let peakRssi: Double     // Peak RSSI in dBm (negative, closest)
    public let readCount: Int
    public let proximity: Int       // Proximity percentage (0-100)
    public let elapsedTimeMs: Int64

    public init(
        targetEpc: String,
        currentRssi: Double = -90.0,
        peakRssi: Double = -90.0,
        readCount: Int = 0,
        proximity: Int = 0,
        elapsedTimeMs: Int64 = 0
    ) {
        self.targetEpc = targetEpc
        self.currentRssi = currentRssi
        self.peakRssi = peakRssi
        self.readCount = readCount
        self.proximity = proximity
        self.elapsedTimeMs = elapsedTimeMs
    }
}
