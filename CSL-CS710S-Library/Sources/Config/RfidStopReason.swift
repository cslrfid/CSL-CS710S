import Foundation

/// Reason for stopping an RFID operation
public enum RfidStopReason: String, CaseIterable {
    case USER_STOPPED = "USER_STOPPED"           // User initiated stop
    case COMPLETED = "COMPLETED"                 // Operation completed naturally
    case ERROR = "ERROR"                         // Error occurred
    case CONNECTION_LOST = "CONNECTION_LOST"     // Reader connection lost
    case TIMEOUT = "TIMEOUT"                     // Operation timed out
}
