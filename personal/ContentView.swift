//
//  ContentView.swift
//  IOSTestApp
//
//  Created by Jack Ahn on 5/19/25.
//

import Foundation
import SwiftUI
import CoreBluetooth

struct BluetoothDevice: Identifiable {
    let id: UUID = UUID()
    let peripheral: CBPeripheral
    let name: String
}

struct SensorUUID {
    // EEG (공통 서비스, Notify & Write)
    static let eegService          = CBUUID(string: "df7b5d95-3afe-00a1-084c-b50895ef4f95")
    static let eegNotifyChar       = CBUUID(string: "00ab4d15-66b4-0d8a-824f-8d6f8966c6e5")
    static let eegWriteChar        = CBUUID(string: "0065cacb-9e52-21bf-a849-99a80d83830e")

    // PPG
    static let ppgService          = CBUUID(string: "1cc50ec0-6967-9d84-a243-c2267f924d1f")
    static let ppgChar             = CBUUID(string: "6c739642-23ba-818b-2045-bfe8970263f6")

    // Accelerometer
    static let accelService        = CBUUID(string: "75c276c3-8f97-20bc-a143-b354244886d4")
    static let accelChar           = CBUUID(string: "d3d46a35-4394-e9aa-5a43-e7921120aaed")

    // Battery
    static let batteryService      = CBUUID(string: "0000180f-0000-1000-8000-00805f9b34fb")
    static let batteryChar         = CBUUID(string: "00002a19-0000-1000-8000-00805f9b34fb")
}



class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    @Published var devices: [BluetoothDevice] = []
    @Published var isScanning = false
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var showBluetoothOffAlert = false
    @Published var connectionStatus: String = "Not Connected"
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func handleEEGData(_ data: Data) {
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

    func handlePPGData(_ data: Data) {
        // 예: [RED_L, RED_H, IR_L, IR_H]
        let bytes = [UInt8](data)

        guard bytes.count >= 4 else { return }

        let red = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        let ir  = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)

        print("PPG - RED: \(red), IR: \(ir)")

        // TODO: BPM, SDNN, SpO₂ 계산 후 update_bpm()
    }

    func handleAccelData(_ data: Data) {
        // 예: [X_L, X_H, Y_L, Y_H, Z_L, Z_H]
        let bytes = [UInt8](data)

        guard bytes.count >= 6 else { return }

        let x = Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let y = Int16(bitPattern: UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
        let z = Int16(bitPattern: UInt16(bytes[4]) | (UInt16(bytes[5]) << 8))

        print("Accel X: \(x), Y: \(y), Z: \(z)")

        // TODO: CSV 저장 및 실시간 그래프
    }

    func handleBatteryData(_ data: Data) {
        guard let level = data.first else { return }
        print("Battery: \(level)%")
        // TODO: UI에 표시
    }


    func startScan() {
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

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func connectToDevice(_ device: BluetoothDevice) {
        centralManager.connect(device.peripheral, options: nil)
        connectionStatus = "Connecting to \(device.name)..."
    }
    
    func disconnect() {
        guard let connected = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(connected)
        connectionStatus = "Disconnecting..."
    }
}


extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
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

    func centralManager(_ central: CBCentralManager,
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

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectionStatus = "Connected to \(peripheral.name ?? "Device")"
        print("✅ Connected to \(peripheral.name ?? "unknown device")")
        
        // ✅ 연결 후 서비스 검색 시작
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "❌ Failed to connect"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Disconnected"
        if connectedPeripheral == peripheral {
            connectedPeripheral = nil
        }
    }
}


extension BluetoothViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
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

    func peripheral(_ peripheral: CBPeripheral,
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



struct ContentView: View {
    @ObservedObject private var bluetoothViewModel = BluetoothViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack {
                    Button("Search") {
                        bluetoothViewModel.startScan()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Button("Stop") {
                        bluetoothViewModel.stopScan()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                if bluetoothViewModel.connectedPeripheral != nil {
                    Button("Disconnect") {
                        bluetoothViewModel.disconnect()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                } else {
                    Button("Disconnect") { }
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(true)
                }

                Text(bluetoothViewModel.isScanning ? "Scanning..." : "Not Scanning")
                Text("🔌 \(bluetoothViewModel.connectionStatus)")

                List(bluetoothViewModel.devices) { device in
                    HStack {
                        Text(device.name)
                        Spacer()
                        Button("Connect") {
                            bluetoothViewModel.connectToDevice(device)
                        }
                        .padding(6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Bluetooth Devices")
            .alert(isPresented: $bluetoothViewModel.showBluetoothOffAlert) {
                Alert(
                    title: Text("Bluetooth is turned off"),
                    message: Text("Please turn on Bluetooth to scan and connect."),
                    dismissButton: .default(Text("Close"))
                )
            }
        }
    }
}


#Preview {
    ContentView()
}
