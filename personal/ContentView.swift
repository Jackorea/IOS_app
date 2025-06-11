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
    @StateObject private var bluetoothKit = BluetoothKit()
    @State private var showingRecordedFiles = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 20) {
                    statusCardSection
                    
                    if bluetoothKit.isConnected {
                        connectedContentSections
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
                    filesButton
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
    
    // MARK: - View Components
    
    private var statusCardSection: some View {
        EnhancedStatusCardView(bluetoothKit: bluetoothKit)
            .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var connectedContentSections: some View {
        // 실시간 센서 데이터
        SensorDataView(bluetoothKit: bluetoothKit)
            .frame(maxWidth: .infinity)
        
        // 배치 데이터 수집 설정 (간소화된 버전 사용)
        SimplifiedBatchDataCollectionView(bluetoothKit: bluetoothKit)
            .frame(maxWidth: .infinity)
        
        // 디바이스 컨트롤
        ControlsView(bluetoothKit: bluetoothKit)
            .frame(maxWidth: .infinity)
    }
    
    private var filesButton: some View {
        Button(action: { showingRecordedFiles = true }) {
            Image(systemName: "folder.fill")
                .font(.title3)
        }
    }
    
    // MARK: - Computed Properties
    
    private var navigationTitle: String {
        switch (bluetoothKit.isConnected, bluetoothKit.isScanning) {
        case (true, _): return "센서 모니터"
        case (false, true): return "스캔 중..."
        case (false, false): return "디바이스 스캐너"
        }
    }
    
    // MARK: - Private Methods
    
    private func openBluetoothSettings() {
        guard let settingsUrl = URL(string: "App-Prefs:Bluetooth") else { return }
        UIApplication.shared.open(settingsUrl)
    }
}

#Preview {
    ContentView()
}
