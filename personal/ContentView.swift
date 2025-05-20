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
    private var centralManager: CBCentralManager
    
    @Published var devices: [BluetoothDevice] = []
    @Published var isScanning = false
    @Published var showBluetoothOffAlert = false

    override init() {
        // ✅ 즉시 초기화
        self.centralManager = CBCentralManager(delegate: nil, queue: .main)
        super.init()
        self.centralManager.delegate = self
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            isScanning = false
            showBluetoothOffAlert = true
            return
        }

        // ✅ 스캔 중이어도 재시작 가능하게 처리
        centralManager.stopScan()
        devices.removeAll()
        centralManager.scanForPeripherals(withServices: nil)
        isScanning = true
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

}

extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is ready")
        case .poweredOff:
            print("Bluetooth is off")
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

        // 기존에 없을 때만 추가
        if !devices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = BluetoothDevice(peripheral: peripheral, name: name)
            devices.append(device)
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

                Text(bluetoothViewModel.isScanning ? "Scanning..." : "Not Scanning")

                List(bluetoothViewModel.devices) { device in
                    Text(device.name)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Bluetooth Devices")
            .alert(isPresented: $bluetoothViewModel.showBluetoothOffAlert) {
                Alert(title: Text("Bluetooth is turned off"),
                      message: Text("Please turn on Bluetooth to scan for devices."),
                      dismissButton: .default(Text("Close")))
            }
        }
    }
}



#Preview {
    ContentView()
}
