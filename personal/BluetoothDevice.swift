import Foundation
import CoreBluetooth

public struct BluetoothDevice: Identifiable {
    public let id: UUID = UUID()
    public let peripheral: CBPeripheral
    public let name: String

    public init(peripheral: CBPeripheral, name: String) {
        self.peripheral = peripheral
        self.name = name
    }
} 