import Foundation

/// Delegate for battery monitoring events
public protocol BatteryDelegate: AnyObject {
    /// Called with updated battery information
    func onBatteryUpdate(_ info: BatteryInfo)

    /// Called when battery monitoring encounters an error
    func onBatteryError(_ error: RfidError)
}
