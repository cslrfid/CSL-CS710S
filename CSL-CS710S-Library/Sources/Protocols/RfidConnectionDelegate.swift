import Foundation

/// Delegate for RFID reader connection events
public protocol RfidConnectionDelegate: AnyObject {
    /// Called when connection process starts
    func onConnecting()

    /// Called when BLE connection is established
    func onConnected(_ reader: RfidReader)

    /// Called when reader is fully initialized and ready for operations
    func onReaderReady(_ reader: RfidReader)

    /// Called when connection attempt fails
    func onConnectionFailed(_ error: RfidError)

    /// Called when reader disconnects (error may be nil for intentional disconnect)
    func onDisconnected(_ reader: RfidReader?, error: RfidError?)
}

/// Default implementations for optional methods
public extension RfidConnectionDelegate {
    func onConnecting() {}
    func onReaderReady(_ reader: RfidReader) {}
}
