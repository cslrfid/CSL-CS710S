import Foundation
import CoreBluetooth

/// Represents an RFID reader device
public struct RfidReader: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let address: String
    public let rssi: Double
    internal let peripheral: CBPeripheral?

    public init(id: UUID = UUID(), name: String, address: String, rssi: Double, peripheral: CBPeripheral? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.rssi = rssi
        self.peripheral = peripheral
    }

    public static func == (lhs: RfidReader, rhs: RfidReader) -> Bool {
        return lhs.address == rhs.address
    }
}
