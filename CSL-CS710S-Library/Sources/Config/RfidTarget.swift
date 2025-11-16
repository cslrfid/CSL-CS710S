import Foundation

/// RFID inventory target flag
public enum RfidTarget: Int, CaseIterable {
    case A = 0          // Target flag A
    case B = 1          // Target flag B
    case AB_FLIP = 2    // Alternate between A and B
}
