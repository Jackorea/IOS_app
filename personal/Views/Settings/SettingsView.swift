import SwiftUI
import BluetoothKit

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bluetooth Settings") {
                    HStack {
                        Text("Auto-reconnect")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("Connection Status")
                        Spacer()
                        Text(bluetoothKit.connectionStatusDescription)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("BluetoothKit Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Supported Devices")
                        Spacer()
                        Text("LXB-series")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(bluetoothKit: BluetoothKit())
} 