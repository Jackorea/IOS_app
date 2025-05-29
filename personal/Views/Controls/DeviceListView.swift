import SwiftUI
import BluetoothKit

// MARK: - Device List

struct DeviceListView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discovered Devices")
                .font(.headline)
            
            if bluetoothKit.discoveredDevices.isEmpty {
                Text("No devices found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(bluetoothKit.discoveredDevices, id: \.id) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Button("Connect") {
                            bluetoothKit.connect(to: device)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Scanning Controls

struct ScanningControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 12) {
            if bluetoothKit.isScanning {
                Button("Stop Scanning") {
                    bluetoothKit.stopScanning()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button("Start Scanning") {
                    bluetoothKit.startScanning()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    DeviceListView(bluetoothKit: BluetoothKit())
} 