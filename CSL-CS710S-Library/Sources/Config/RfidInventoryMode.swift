import Foundation

/// RFID inventory mode
public enum RfidInventoryMode: String, CaseIterable {
    case COMPACT = "COMPACT"       // Compact mode (recommended for CS710S)
    case STANDARD = "STANDARD"     // Standard mode
}
