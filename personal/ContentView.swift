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
    private var scanTimer: Timer?

    // ✅ 기존 peripheral 배열 제거하고 새로운 모델 배열 사용
    @Published var devices: [BluetoothDevice] = []
    @Published var isScanning = false
    @Published var showBluetoothOffAlert = false

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        startExpirationTimer() // ✅ 디바이스 사라짐 감지를 위한 타이머 시작
    }

    func startScan() {
        if centralManager.state == .poweredOn && !isScanning {
            devices.removeAll()
            centralManager.scanForPeripherals(withServices: nil)
            isScanning = true
        } else if centralManager.state != .poweredOn {
            isScanning = false
            showBluetoothOffAlert = true
        }
    }

    func stopScan() {
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        }
    }

    // ✅ 주기적으로 lastSeen 오래된 디바이스 제거
    private func startExpirationTimer() {
        scanTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let now = Date()
            self.devices.removeAll { now.timeIntervalSince($0.lastSeen) > 5.0 }
        }
    }
}


extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is ready")
        } else {
            print("Bluetooth not available")
            isScanning = false // ✅ 블루투스 꺼지면 상태 초기화
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        let name = peripheral.name ?? ""
        
        // ✅ "LXB-"로 시작하는 이름만 처리
        guard name.hasPrefix("LXB-") else { return }

        // ✅ 같은 identifier를 가진 디바이스가 이미 있다면 lastSeen만 업데이트
        if let index = devices.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            devices[index].lastSeen = Date()
        } else {
            // ✅ 새로운 디바이스 추가
            let newDevice = BluetoothDevice(peripheral: peripheral, name: name, lastSeen: Date())
            devices.append(newDevice)
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

                // ✅ List 업데이트: peripheralNames → devices
                List(bluetoothViewModel.devices) { device in
                    Text(device.name)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Bluetooth Devices")
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
