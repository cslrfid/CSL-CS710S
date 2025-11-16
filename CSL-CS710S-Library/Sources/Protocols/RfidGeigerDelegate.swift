import Foundation

/// Delegate for Geiger search (tag locating) events
public protocol RfidGeigerDelegate: AnyObject {
    /// Called when search starts
    func onSearchStarted()

    /// Called with proximity update
    func onProximityUpdate(_ stats: RfidGeigerStats)

    /// Called when search stops
    func onSearchStopped(_ reason: RfidStopReason)

    /// Called when search encounters an error
    func onSearchError(_ error: RfidError)
}

/// Default implementations for optional methods
public extension RfidGeigerDelegate {
    func onSearchStarted() {}
}
