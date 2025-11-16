import Foundation

/// Delegate for RFID reader scanning events
public protocol RfidScanDelegate: AnyObject {
    /// Called when a new reader is discovered
    func onReaderDiscovered(_ reader: RfidReader)

    /// Called when scanning encounters an error
    func onScanError(_ error: RfidError)
}
