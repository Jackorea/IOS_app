//
//  ContentView.swift
//  personal
//
//  BluetoothKit 기능을 시연하는 향상된 예제 앱
//

import Foundation
import SwiftUI
import CoreBluetooth
import BluetoothKit
import UniformTypeIdentifiers

// BluetoothDevice struct가 여기에 있다면 제거
// SensorUUID struct가 여기에 있다면 제거

// BluetoothViewModel 클래스와 확장들은 이동될 예정

struct ContentView: View {
    @StateObject private var bluetoothKit: BluetoothKit
    @State private var showingRecordedFiles = false

    init() {
        self._bluetoothKit = StateObject(wrappedValue: BluetoothKit())
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // 향상된 상태 카드 (이제 스캔 컨트롤과 디바이스 목록 포함)
                    EnhancedStatusCardView(bluetoothKit: bluetoothKit)
                        .frame(maxWidth: .infinity)
                    
                    // 실시간 데이터 표시 및 컨트롤 (연결된 경우에만)
                    if bluetoothKit.isConnected {
                        SensorDataView(bluetoothKit: bluetoothKit)
                            .frame(maxWidth: .infinity)
                        RecordingControlsView(bluetoothKit: bluetoothKit)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // 향상된 컨트롤 (연결된 경우에만)
                    if bluetoothKit.isConnected {
                        ControlsView(bluetoothKit: bluetoothKit)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .clipped()
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingRecordedFiles = true }) {
                        Image(systemName: "folder.fill")
                    }
                }
            }
            .alert("Bluetooth가 꺼져 있습니다", isPresented: $bluetoothKit.isBluetoothDisabled) {
                Button("설정", action: openBluetoothSettings)
                Button("닫기", role: .cancel) { }
            } message: {
                Text("센서 디바이스를 스캔하고 연결하려면 Bluetooth를 켜주세요.")
            }
            .sheet(isPresented: $showingRecordedFiles) {
                RecordedFilesView(bluetoothKit: bluetoothKit)
            }
        }
    }
    
    private var navigationTitle: String {
        if bluetoothKit.isConnected {
            return "센서 모니터"
        } else if bluetoothKit.isScanning {
            return "스캔 중..."
        } else {
            return "디바이스 스캐너"
        }
    }
    
    private func openBluetoothSettings() {
        if let settingsUrl = URL(string: "App-Prefs:Bluetooth") {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    ContentView()
}
