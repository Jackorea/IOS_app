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
