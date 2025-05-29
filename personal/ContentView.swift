//
//  ContentView.swift
//  personal
//
//  Enhanced example app demonstrating BluetoothKit capabilities
//

import Foundation
import SwiftUI
import CoreBluetooth
import BluetoothKit
import UniformTypeIdentifiers

// REMOVE BluetoothDevice struct if it exists here
// REMOVE SensorUUID struct if it exists here

// BluetoothViewModel class and its extensions will be moved

struct ContentView: View {
    @StateObject private var bluetoothKit: BluetoothKit
    @State private var showingSettings = false
    @State private var showingRecordedFiles = false

    init() {
        self._bluetoothKit = StateObject(wrappedValue: BluetoothKit())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Enhanced Status Card
                    EnhancedStatusCardView(bluetoothKit: bluetoothKit)
                    
                    // Real-time Data Display (only when connected)
                    if bluetoothKit.isConnected {
                        SensorDataView(bluetoothKit: bluetoothKit)
                        RecordingControlsView(bluetoothKit: bluetoothKit)
                    } else {
                        ScanningControlsView(bluetoothKit: bluetoothKit)
                        DeviceListView(bluetoothKit: bluetoothKit)
                    }
                    
                    // Enhanced Controls
                    ControlsView(bluetoothKit: bluetoothKit)
                }
                .padding()
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingRecordedFiles = true }) {
                        Image(systemName: "folder.fill")
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .alert("Bluetooth is turned off", isPresented: $bluetoothKit.showBluetoothOffAlert) {
                Button("Settings", action: openBluetoothSettings)
                Button("Close", role: .cancel) { }
            } message: {
                Text("Please turn on Bluetooth to scan and connect to sensor devices.")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(bluetoothKit: bluetoothKit)
            }
            .sheet(isPresented: $showingRecordedFiles) {
                RecordedFilesView(bluetoothKit: bluetoothKit)
            }
        }
    }
    
    private var navigationTitle: String {
        if bluetoothKit.isConnected {
            return "Sensor Monitor"
        } else if bluetoothKit.isScanning {
            return "Scanning..."
        } else {
            return "Device Scanner"
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
