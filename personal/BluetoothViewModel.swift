import Foundation
import SwiftUI
import CoreBluetooth

public class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    @Published public var devices: [BluetoothDevice] = []
    @Published public var isScanning = false
    @Published public var connectedPeripheral: CBPeripheral? = nil
    @Published public var showBluetoothOffAlert = false
    @Published public var connectionStatus: String = "Not Connected"
    @Published public var autoReconnectEnabled: Bool = true // 오토커넥션 여부
    
    private var lastConnectedPeripheralIdentifier: UUID? // 마지막 연결된 기기 ID
    private var userInitiatedDisconnect: Bool = false // 사용자에 의한 연결 해제 여부
    
    override public init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    public func handleEEGData(_ data: Data) {
        // 예: [CH1_L, CH1_H, CH2_L, CH2_H, LeadOffFlag]
        let bytes = [UInt8](data)

        guard bytes.count >= 5 else { return }

        let ch1 = Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let ch2 = Int16(bitPattern: UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
        let leadOff = bytes[4] != 0

        let ch1uV = Double(ch1) * 0.195
        let ch2uV = Double(ch2) * 0.195

        print("EEG CH1: \(ch1uV) µV, CH2: \(ch2uV) µV, LeadOff: \(leadOff)")

        // TODO: 저장, 그래프, FFT 처리
    }

    public func handlePPGData(_ data: Data) {
        // 예: [RED_L, RED_H, IR_L, IR_H]
        let bytes = [UInt8](data)

        guard bytes.count >= 4 else { return }

        let red = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        let ir  = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)

        print("PPG - RED: \(red), IR: \(ir)")

        // TODO: BPM, SDNN, SpO₂ 계산 후 update_bpm()
    }

    public func handleAccelData(_ data: Data) {
        // 예: [X_L, X_H, Y_L, Y_H, Z_L, Z_H]
        let bytes = [UInt8](data)

        guard bytes.count >= 6 else { return }

        let x = Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let y = Int16(bitPattern: UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
        let z = Int16(bitPattern: UInt16(bytes[4]) | (UInt16(bytes[5]) << 8))

        print("Accel X: \(x), Y: \(y), Z: \(z)")

        // TODO: CSV 저장 및 실시간 그래프
    }

    public func handleBatteryData(_ data: Data) {
        guard let level = data.first else { return }
        print("Battery: \(level)%")
        // TODO: UI에 표시
    }


    public func startScan() {
        guard centralManager.state == .poweredOn else {
            isScanning = false
            showBluetoothOffAlert = true
            return
        }
        centralManager.stopScan()
        devices.removeAll()
        centralManager.scanForPeripherals(withServices: nil)
        isScanning = true
    }

    public func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    public func connectToDevice(_ device: BluetoothDevice) {
        centralManager.connect(device.peripheral, options: nil)
        connectionStatus = "Connecting to \(device.name)..."
    }
    
    public func disconnect() {
        guard let connected = connectedPeripheral else { return }
        userInitiatedDisconnect = true // 사용자가 연결 해제 시도
        centralManager.cancelPeripheralConnection(connected)
        connectionStatus = "Disconnecting..."
    }
}


extension BluetoothViewModel: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            isScanning = false
        default:
            isScanning = false
        }
    }

    public func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? ""
        guard name.hasPrefix("LXB-") else { return }

        if !devices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = BluetoothDevice(peripheral: peripheral, name: name)
            devices.append(device)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectionStatus = "Connected to \(peripheral.name ?? "Device")"
        print("✅ Connected to \(peripheral.name ?? "unknown device")")
        stopScan() // 스캔 중지
        lastConnectedPeripheralIdentifier = peripheral.identifier // 마지막 연결 기기 ID 저장
        userInitiatedDisconnect = false // 연결 성공 시 플래그 리셋
        
        // ✅ 연결 후 서비스 검색 시작
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "❌ Failed to connect"
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Disconnected"
        let disconnectedPeripheralName = peripheral.name ?? "device"
        print("Bluetooth device \(disconnectedPeripheralName) disconnected with error: \(error?.localizedDescription ?? "None")")

        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }

        // 오토커넥션 로직
        if !userInitiatedDisconnect && autoReconnectEnabled,
           let lastID = lastConnectedPeripheralIdentifier,
           peripheral.identifier == lastID {
            print("Attempting to auto-reconnect to \(disconnectedPeripheralName)...")
            connectionStatus = "Reconnecting to \(disconnectedPeripheralName)..."
            centralManager.connect(peripheral, options: nil)
        } else if userInitiatedDisconnect {
            // 사용자에 의한 연결 해제였으면 플래그 리셋
            lastConnectedPeripheralIdentifier = nil 
            userInitiatedDisconnect = false
            print("User initiated disconnect. Auto-reconnect will not be attempted for \(disconnectedPeripheralName).")
        }
    }
}


extension BluetoothViewModel: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case SensorUUID.eegNotifyChar,
                 SensorUUID.ppgChar,
                 SensorUUID.accelChar,
                 SensorUUID.batteryChar:
                peripheral.setNotifyValue(true, for: characteristic)
                print("🔔 Notify enabled for: \(characteristic.uuid)")

            default:
                break
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case SensorUUID.eegNotifyChar:
            handleEEGData(data)
        case SensorUUID.ppgChar:
            handlePPGData(data)
        case SensorUUID.accelChar:
            handleAccelData(data)
        case SensorUUID.batteryChar:
            handleBatteryData(data)
        default:
            break
        }
    }
} 