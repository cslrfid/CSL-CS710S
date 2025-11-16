import Foundation

/// Delegate for RFID configuration events
public protocol RfidConfigurationDelegate: AnyObject {
    /// Called when configuration is successfully applied
    func onConfigured()

    /// Called when configuration fails
    func onConfigurationFailed(_ error: RfidError)
}
