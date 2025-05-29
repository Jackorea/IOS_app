import SwiftUI
import BluetoothKit

// MARK: - Enhanced Status Card View

struct EnhancedStatusCardView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Connection Status Icon
                Image(systemName: connectionIcon)
                    .font(.system(size: 24))
                    .foregroundColor(connectionColor)
                    .symbolEffect(.bounce, value: bluetoothKit.connectionState)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bluetoothKit.connectionStatusDescription)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if bluetoothKit.isConnected {
                        Text("Ready for data collection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
            
            // Progress indicator for scanning
            if bluetoothKit.isScanning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)
            }
            
            // Data rate information when connected
            if bluetoothKit.isConnected {
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