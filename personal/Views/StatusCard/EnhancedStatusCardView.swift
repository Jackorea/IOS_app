import SwiftUI
import BluetoothKit

// MARK: - Enhanced Status Card View

/// BluetoothKit의 연결 상태와 컨트롤을 보여주는 향상된 상태 카드 뷰
struct EnhancedStatusCardView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 16) {
            connectionHeader
            
            if !bluetoothKit.isConnected {
                disconnectedContent
            } else {
                connectedContent
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
    }
    
    private var connectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(bluetoothKit.connectionStatusDescription)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Image(systemName: connectionIcon)
                        .font(.system(size: 16))
                        .foregroundColor(connectionColor)
                        .symbolEffect(.bounce, value: bluetoothKit.connectionState)
                }
                
                if case .connected = bluetoothKit.connectionState {
                    Text("샘플링 레이트")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    Text("EEG: 250Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("PPG: 50Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("ACC: 30Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            recordingIndicator
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var recordingIndicator: some View {
        if bluetoothKit.isRecording {
            VStack {
                Image(systemName: "record.circle.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse)
                Text("기록")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
        }
    }
    
    private var disconnectedContent: some View {
        VStack(spacing: 16) {
            scanControls
            Divider()
            autoReconnectToggle
            deviceList
        }
    }
    
    private var scanControls: some View {
        VStack(spacing: 12) {
            if bluetoothKit.isScanning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                Button("스캔 중지") {
                    bluetoothKit.stopScanning()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button("스캔 시작") {
                    bluetoothKit.startScanning()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var autoReconnectToggle: some View {
        HStack {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.blue)
                .font(.subheadline)
            
            Text("자동 재연결")
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
    }
    
    @ViewBuilder
    private var deviceList: some View {
        if !bluetoothKit.discoveredDevices.isEmpty {
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("발견된 디바이스")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(0..<bluetoothKit.discoveredDevices.count, id: \.self) { index in
                    let device = bluetoothKit.discoveredDevices[index]
                    deviceRow(for: device)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func deviceRow(for device: BluetoothDevice) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button("연결") {
                bluetoothKit.connect(to: device)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(deviceRowBackground)
    }
    
    private var deviceRowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.blue.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
    }
    
    private var connectedContent: some View {
        VStack(spacing: 16) {
            Divider()
            dataRateIndicators
        }
    }
    
    private var dataRateIndicators: some View {
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
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.1))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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

/// 센서 상태를 표시하는 데이터 레이트 인디케이터 컴포넌트
struct DataRateIndicator: View {
    let title: String
    let hasData: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(hasData ? .green : .gray)
                .symbolEffect(.pulse, value: hasData)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Circle()
                .fill(hasData ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
        }
    }
}

#Preview {
    EnhancedStatusCardView(bluetoothKit: BluetoothKit())
} 