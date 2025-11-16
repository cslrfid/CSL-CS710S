import Foundation

/// Delegate for hardware trigger button events
public protocol TriggerDelegate: AnyObject {
    /// Called when trigger state changes
    /// - Parameter pressed: true when pressed, false when released
    func onTriggerStateChanged(_ pressed: Bool)
}
