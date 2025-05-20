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
    var lastSeen: Date
}

class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var peripherals: [CBPeripheral] = []

    @Published var peripheralNames: [String] = []
    @Published var isScanning = false
    @Published var showBluetoothOffAlert = false // ✅ alert 상태 변수

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        if centralManager.state == .poweredOn && !isScanning {
            peripherals.removeAll()
            peripheralNames.removeAll()
            centralManager.scanForPeripherals(withServices: nil)
            isScanning = true
        } else if centralManager.state != .poweredOn {
            isScanning = false
            showBluetoothOffAlert = true // ✅ 블루투스 꺼져있으면 alert 표시
        }
    }

    func stopScan() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        }
    }
}


extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is ready")
        } else {
            print("Bluetooth not available")
            isScanning = false // ✅ 블루투스 꺼지면 자동으로 상태 변경
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        // 장치 이름 가져오기 (nil일 경우 ""로 처리)
        let name = peripheral.name ?? ""

        // ✅ "LXB-"로 시작하지 않으면 무시
        guard name.hasPrefix("LXB-") else { return }

        // ✅ 중복 방지 후 추가
        if !peripherals.contains(peripheral) {
            peripherals.append(peripheral)
            peripheralNames.append(name)
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

                List(bluetoothViewModel.peripheralNames, id: \.self) { name in
                    Text(name)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Bluetooth Devices")
            // ✅ Alert 추가
            .alert(isPresented: $bluetoothViewModel.showBluetoothOffAlert) {
                Alert(
                    title: Text("Bluetooth is turned off"),
                    message: Text("Please turn on Bluetooth to scan for devices."),
                    dismissButton: .default(Text("Close"))
                )
            }
        }
    }
}



#Preview {
    ContentView()
}
