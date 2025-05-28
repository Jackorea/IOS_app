//
//  ContentView.swift
//  IOSTestApp
//
//  Created by Jack Ahn on 5/19/25.
//

import Foundation
import SwiftUI
import CoreBluetooth

// REMOVE BluetoothDevice struct if it exists here
// REMOVE SensorUUID struct if it exists here

// BluetoothViewModel class and its extensions will be moved

struct ContentView: View {
    @ObservedObject private var bluetoothViewModel = BluetoothViewModel()
    @State private var isAnimating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: bluetoothViewModel.connectedPeripheral != nil ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                                .font(.system(size: 24))
                                .foregroundColor(bluetoothViewModel.connectedPeripheral != nil ? .green : .gray)
                            
                            Text(bluetoothViewModel.connectionStatus)
                                .font(.headline)
                        }
                        
                        if bluetoothViewModel.isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    
                    // Real-time Data Display (only when connected)
                    if bluetoothViewModel.connectedPeripheral != nil {
                        VStack(spacing: 16) {
                            // EEG Data Card
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                        .font(.title2)
                                    Text("EEG Data")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    Spacer()
                                    // Lead-off status indicator
                                    Image(systemName: bluetoothViewModel.lastEEGReading.leadOff ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .foregroundColor(bluetoothViewModel.lastEEGReading.leadOff ? .red : .green)
                                }
                                
                                HStack(spacing: 20) {
                                    VStack {
                                        Text("CH1")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(String(format: "%.1f µV", bluetoothViewModel.lastEEGReading.ch1))
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    VStack {
                                        Text("CH2")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(String(format: "%.1f µV", bluetoothViewModel.lastEEGReading.ch2))
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    VStack {
                                        Text("Status")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(bluetoothViewModel.lastEEGReading.leadOff ? "Disconnected" : "Connected")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(bluetoothViewModel.lastEEGReading.leadOff ? .red : .green)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            // PPG Data Card
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                    Text("PPG Data")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                
                                HStack(spacing: 30) {
                                    VStack {
                                        Text("Red")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(bluetoothViewModel.lastPPGReading.red)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    VStack {
                                        Text("IR")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(bluetoothViewModel.lastPPGReading.ir)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            // Accelerometer Data Card
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "move.3d")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    Text("Accelerometer")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                                
                                HStack(spacing: 20) {
                                    VStack {
                                        Text("X")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(bluetoothViewModel.lastAccelReading.x)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    VStack {
                                        Text("Y")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(bluetoothViewModel.lastAccelReading.y)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    VStack {
                                        Text("Z")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(bluetoothViewModel.lastAccelReading.z)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Recording Controls (when connected)
                        VStack(spacing: 12) {
                            if !bluetoothViewModel.isRecording {
                                Button(action: {
                                    withAnimation {
                                        bluetoothViewModel.startRecording()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "record.circle")
                                        Text("Start Recording")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            } else {
                                Button(action: {
                                    withAnimation {
                                        bluetoothViewModel.stopRecording()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "stop.circle")
                                        Text("Stop Recording")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                            
                            Button(action: {
                                withAnimation {
                                    bluetoothViewModel.disconnect()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "link.badge.minus")
                                    Text("Disconnect")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    } else {
                        // Control Buttons (when not connected)
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation {
                                    bluetoothViewModel.startScan()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                    Text("Search")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                            if bluetoothViewModel.isScanning {
                                Button(action: {
                                    withAnimation {
                                        bluetoothViewModel.stopScan()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text("Stop")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        // Device List (only when not connected)
                        if !bluetoothViewModel.devices.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Available Devices")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                ForEach(bluetoothViewModel.devices) { device in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(device.name)
                                                .font(.headline)
                                            Text("Tap to connect")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            withAnimation {
                                                bluetoothViewModel.connectToDevice(device)
                                            }
                                        }) {
                                            Text("Connect")
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.green)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                    
                    // Auto-reconnect toggle
                    HStack {
                        Text("Auto-reconnect")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $bluetoothViewModel.autoReconnectEnabled)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .padding()
            }
            .navigationTitle(bluetoothViewModel.connectedPeripheral != nil ? "Sensor Monitor" : "Device Scanner")
            .navigationBarTitleDisplayMode(.large)
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
