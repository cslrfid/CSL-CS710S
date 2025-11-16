import Foundation

/// Delegate for RFID inventory events
public protocol RfidInventoryDelegate: AnyObject {
    /// Called when a tag is read
    func onTagRead(_ tag: RfidTag)

    /// Called with updated inventory statistics
    func onInventoryRound(_ stats: RfidInventoryStats)

    /// Called when inventory operation stops
    func onInventoryStopped(_ reason: RfidStopReason)

    /// Called when inventory encounters an error
    func onInventoryError(_ error: RfidError)
}

/// Default implementations for optional methods
public extension RfidInventoryDelegate {
    func onInventoryRound(_ stats: RfidInventoryStats) {}
}
