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
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
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
                    
                    // Control Buttons
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
                    
                    if bluetoothViewModel.connectedPeripheral != nil {
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
                    
                    // Device List
                    List {
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
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    Toggle("Auto-reconnect", isOn: $bluetoothViewModel.autoReconnectEnabled)
                        .padding(.horizontal)
                }
                .padding()
            }
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
