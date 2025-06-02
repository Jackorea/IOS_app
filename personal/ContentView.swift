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
    @State private var showingRecordedFiles = false

    init() {
        self._bluetoothKit = StateObject(wrappedValue: BluetoothKit())
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Enhanced Status Card (now includes scanning controls and device list)
                    EnhancedStatusCardView(bluetoothKit: bluetoothKit)
                        .frame(maxWidth: .infinity)
                    
                    // Real-time Data Display and Controls (only when connected)
                    if bluetoothKit.isConnected {
                        SensorDataView(bluetoothKit: bluetoothKit)
                            .frame(maxWidth: .infinity)
                        RecordingControlsView(bluetoothKit: bluetoothKit)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Enhanced Controls (only when connected)
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
            .alert("Bluetooth is turned off", isPresented: $bluetoothKit.isBluetoothDisabled) {
                Button("Settings", action: openBluetoothSettings)
                Button("Close", role: .cancel) { }
            } message: {
                Text("Please turn on Bluetooth to scan and connect to sensor devices.")
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
