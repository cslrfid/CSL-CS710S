import Foundation

/// Barcode scan result
public struct BarcodeData: Identifiable {
    public let id: UUID
    public let barcode: String
    public let timestamp: TimeInterval

    public init(barcode: String, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = UUID()
        self.barcode = barcode
        self.timestamp = timestamp
    }
}

/// Barcode scanning statistics
public struct BarcodeStats {
    public let totalScans: Int
    public let uniqueBarcodes: Int
    public let elapsedTimeMs: Int64

    public init(totalScans: Int = 0, uniqueBarcodes: Int = 0, elapsedTimeMs: Int64 = 0) {
        self.totalScans = totalScans
        self.uniqueBarcodes = uniqueBarcodes
        self.elapsedTimeMs = elapsedTimeMs
    }
}
