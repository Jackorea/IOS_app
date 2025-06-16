import SwiftUI
import BluetoothKit

// MARK: - Enhanced Status Card View

/// BluetoothKit의 연결 상태와 컨트롤을 보여주는 향상된 상태 카드 뷰
struct EnhancedStatusCardView: View {
    @ObservedObject var bluetoothViewModel: BluetoothKitViewModel
    @State private var isFirstConnection = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                deviceIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetoothViewModel.isConnected ? "디바이스 연결됨" : "연결 대기 중")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(bluetoothViewModel.isConnected ? .green : .primary)
                    
                    Text(bluetoothViewModel.connectionStatusDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 연결 상태 표시
                connectionStatusIndicator
            }
            
            if !bluetoothViewModel.isConnected {
                discoveredDevicesSection
            } else {
                connectedDeviceSection
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onChange(of: bluetoothViewModel.isConnected) { isConnected in
            if isConnected && isFirstConnection {
                isFirstConnection = false
            }
        }
    }
    
    // MARK: - View Components
    
    private var deviceIcon: some View {
        Image(systemName: bluetoothViewModel.isConnected ? "sensor.tag.radiowaves.forward.fill" : "sensor.tag.radiowaves.forward")
            .font(.system(size: 24))
            .foregroundColor(bluetoothViewModel.isConnected ? .blue : .gray)
            .symbolEffect(.variableColor, isActive: bluetoothViewModel.isConnected)
    }
    
    private var connectionStatusIndicator: some View {
        HStack(spacing: 8) {
            if bluetoothViewModel.isScanning {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
            
            Circle()
                .fill(bluetoothViewModel.isConnected ? Color.green : (bluetoothViewModel.isScanning ? Color.blue : Color.gray))
                .frame(width: 12, height: 12)
                .symbolEffect(.pulse, isActive: bluetoothViewModel.isScanning)
        }
    }
    
    @ViewBuilder
    private var discoveredDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("디바이스 검색")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(bluetoothViewModel.isScanning ? "중지" : "스캔") {
                    if bluetoothViewModel.isScanning {
                        bluetoothViewModel.stopScanning()
                    } else {
                        bluetoothViewModel.startScanning()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
            
            if bluetoothViewModel.discoveredDevices.isEmpty {
                if bluetoothViewModel.isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("디바이스를 찾는 중...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                } else {
                    Text("스캔 버튼을 눌러 LinkBand 디바이스를 찾아보세요.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(bluetoothViewModel.discoveredDevices.prefix(3)) { device in
                        deviceRowView(device: device)
                    }
                    
                    if bluetoothViewModel.discoveredDevices.count > 3 {
                        Text("\(bluetoothViewModel.discoveredDevices.count - 3)개 더...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var connectedDeviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("연결된 디바이스")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("연결 해제") {
                    bluetoothViewModel.disconnect()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            // 데이터 수신 상태
            dataReceptionStatus
            
            // 자동 재연결 설정
            autoReconnectToggle
        }
    }
    
    private var dataReceptionStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("실시간 데이터")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                DataRateIndicator(
                    title: "EEG",
                    hasData: bluetoothViewModel.latestEEGReading != nil,
                    color: .purple
                )
                
                DataRateIndicator(
                    title: "PPG",
                    hasData: bluetoothViewModel.latestPPGReading != nil,
                    color: .red
                )
                
                DataRateIndicator(
                    title: "ACC",
                    hasData: bluetoothViewModel.latestAccelerometerReading != nil,
                    color: .blue
                )
                
                DataRateIndicator(
                    title: "BAT",
                    hasData: bluetoothViewModel.latestBatteryReading != nil,
                    color: .green
                )
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private var autoReconnectToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("자동 재연결")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("연결이 끊어지면 자동으로 재연결합니다")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { bluetoothViewModel.isAutoReconnectEnabled },
                set: { bluetoothViewModel.setAutoReconnect(enabled: $0) }
            ))
            .toggleStyle(SwitchToggleStyle())
        }
        .padding(.vertical, 8)
    }
    
    private func deviceRowView(device: BluetoothDevice) -> some View {
        Button(action: {
            bluetoothViewModel.connect(to: device)
        }) {
            HStack {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("LinkBand 센서")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Data Rate Indicator

struct DataRateIndicator: View {
    let title: String
    let hasData: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(hasData ? color : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .symbolEffect(.pulse, isActive: hasData)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(hasData ? color : .secondary)
        }
    }
}

#Preview {
    EnhancedStatusCardView(bluetoothViewModel: BluetoothKitViewModel())
        .padding()
} 