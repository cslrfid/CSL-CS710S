import Foundation

/// Delegate for barcode scanning events
public protocol BarcodeScanDelegate: AnyObject {
    /// Called when a barcode is scanned
    func onBarcodeScanned(_ data: BarcodeData)

    /// Called with updated barcode statistics
    func onStatisticsUpdate(_ stats: BarcodeStats)

    /// Called when barcode scanning encounters an error
    func onScanError(_ error: RfidError)
}

/// Default implementations for optional methods
public extension BarcodeScanDelegate {
    func onStatisticsUpdate(_ stats: BarcodeStats) {}
}
