import Foundation

/// Inventory operation statistics
public struct RfidInventoryStats {
    public let uniqueTagCount: Int
    public let totalReads: Int
    public let readRate: Double  // Tags per second
    public let elapsedTimeMs: Int64

    public init(
        uniqueTagCount: Int = 0,
        totalReads: Int = 0,
        readRate: Double = 0.0,
        elapsedTimeMs: Int64 = 0
    ) {
        self.uniqueTagCount = uniqueTagCount
        self.totalReads = totalReads
        self.readRate = readRate
        self.elapsedTimeMs = elapsedTimeMs
    }
}
