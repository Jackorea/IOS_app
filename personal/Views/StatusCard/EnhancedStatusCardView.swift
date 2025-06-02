import SwiftUI
import BluetoothKit

// MARK: - Enhanced Status Card View

/// BluetoothKit의 연결 상태와 컨트롤을 보여주는 향상된 상태 카드 뷰
struct EnhancedStatusCardView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 16) {
            // 연결 상태 헤더
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
                
                // 녹화 상태
                if bluetoothKit.isRecording {
                    VStack {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                            .symbolEffect(.pulse)
                        Text("녹화")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            if !bluetoothKit.isConnected {
                // 스캔 컨트롤
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
                
                // Auto-reconnect 토글
                Divider()
                
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
                
                // Device Scanner
                if !bluetoothKit.discoveredDevices.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("발견된 디바이스")
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
                                
                                Button("연결") {
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
                // 연결되었을 때 데이터 레이트 정보
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