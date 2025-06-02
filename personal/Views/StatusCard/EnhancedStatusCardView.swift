import SwiftUI
import BluetoothKit

// MARK: - Enhanced Status Card View

/// Enhanced status card view that shows connection state and controls for BluetoothKit
struct EnhancedStatusCardView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection Status Header
            HStack {
                Image(systemName: connectionIcon)
                    .font(.system(size: 24))
                    .foregroundColor(connectionColor)
                    .symbolEffect(.bounce, value: bluetoothKit.connectionState)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bluetoothKit.connectionStatusDescription)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Recording Status
                if bluetoothKit.isRecording {
                    VStack {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                            .symbolEffect(.pulse)
                        Text("REC")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            if !bluetoothKit.isConnected {
                // Scanning Controls
                VStack(spacing: 12) {
                    if bluetoothKit.isScanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
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
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Auto-reconnect toggle
                Divider()
                
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    
                    Text("Auto-reconnect")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $bluetoothKit.isAutoReconnectEnabled)
                        .labelsHidden()
                        .onChange(of: bluetoothKit.isAutoReconnectEnabled) { newValue in
                            bluetoothKit.setAutoReconnect(enabled: newValue)
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                
                // Device List
                if !bluetoothKit.discoveredDevices.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discovered Devices")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(bluetoothKit.discoveredDevices, id: \.id) { device in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Data rate information when connected
                Divider()
                
                HStack {
                    DataRateIndicator(
                        title: "EEG",
                        hasData: bluetoothKit.latestEEGReading != nil,
                        icon: "brain.head.profile"
                    )
                    
                    Spacer()
                    
                    DataRateIndicator(
                        title: "PPG",
                        hasData: bluetoothKit.latestPPGReading != nil,
                        icon: "heart.fill"
                    )
                    
                    Spacer()
                    
                    DataRateIndicator(
                        title: "ACCEL",
                        hasData: bluetoothKit.latestAccelerometerReading != nil,
                        icon: "move.3d"
                    )
                    
                    Spacer()
                    
                    DataRateIndicator(
                        title: "BATT",
                        hasData: bluetoothKit.latestBatteryReading != nil,
                        icon: "battery.75"
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var connectionIcon: String {
        switch bluetoothKit.connectionState {
        case .disconnected:
            return "wave.3.right.circle"
        case .scanning:
            return "magnifyingglass.circle"
        case .connecting:
            return "arrow.triangle.2.circlepath.circle"
        case .connected:
            return "wave.3.right.circle.fill"
        case .reconnecting:
            return "arrow.clockwise.circle"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var connectionColor: Color {
        switch bluetoothKit.connectionState {
        case .disconnected:
            return .gray
        case .scanning:
            return .blue
        case .connecting, .reconnecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}

/// Data rate indicator component for showing sensor status
struct DataRateIndicator: View {
    let title: String
    let hasData: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(hasData ? .green : .gray)
                .symbolEffect(.pulse, isActive: hasData)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(hasData ? .green : .gray)
        }
    }
}

#Preview {
    EnhancedStatusCardView(bluetoothKit: BluetoothKit())
} 