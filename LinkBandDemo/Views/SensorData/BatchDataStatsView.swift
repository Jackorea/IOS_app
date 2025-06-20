import SwiftUI
// BluetoothKitViewModel import 추가 - 어댑터 사용

// MARK: - Batch Data Statistics View

/// 센서 데이터 통계를 표시하는 뷰
struct BatchDataStatsView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("센서 데이터 통계")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if bluetoothKit.isRecording {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                        .symbolEffect(.pulse)
                }
            }
            
            Divider()
            
            if !bluetoothKit.isConnected {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    if bluetoothKit.latestEEGReading != nil {
                        sensorStatCard(for: "EEG", icon: "brain.head.profile", color: .purple)
                    }
                    
                    if bluetoothKit.latestPPGReading != nil {
                        sensorStatCard(for: "PPG", icon: "heart.fill", color: .red)
                    }
                    
                    if bluetoothKit.latestAccelerometerReading != nil {
                        sensorStatCard(for: "가속도계", icon: "move.3d", color: .blue)
                    }
                    
                    if bluetoothKit.latestBatteryReading != nil {
                        sensorStatCard(for: "배터리", icon: "battery.75", color: .green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("센서 데이터 없음")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("디바이스에 연결하고 데이터 수신을 시작하면 통계가 여기에 표시됩니다.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private func sensorStatCard(for sensorType: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            // 센서 타입 헤더
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(sensorType)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("실시간 데이터")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 현재 센서 값 표시
            sensorDataView(for: sensorType, color: color)
            
            // 연결 상태 정보
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("연결 상태")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(bluetoothKit.connectionStatusDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("기록 상태")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(bluetoothKit.isRecording ? "기록 중" : "대기")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(bluetoothKit.isRecording ? .red : .gray)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func sensorDataView(for sensorType: String, color: Color) -> some View {
        switch sensorType {
        case "EEG":
            if let eeg = bluetoothKit.latestEEGReading {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    StatItem(title: "CH1", value: String(format: "%.1f µV", eeg.channel1), color: color)
                    StatItem(title: "CH2", value: String(format: "%.1f µV", eeg.channel2), color: color)
                }
            }
            
        case "PPG":
            if let ppg = bluetoothKit.latestPPGReading {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    StatItem(title: "Red", value: "\(ppg.red)", color: color)
                    StatItem(title: "IR", value: "\(ppg.ir)", color: color)
                }
            }
            
        case "가속도계":
            if let accel = bluetoothKit.latestAccelerometerReading {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    StatItem(title: "X", value: "\(accel.x)", color: color)
                    StatItem(title: "Y", value: "\(accel.y)", color: color)
                    StatItem(title: "Z", value: "\(accel.z)", color: color)
                }
            }
            
        case "배터리":
            if let battery = bluetoothKit.latestBatteryReading {
                StatItem(title: "배터리", value: "\(battery.level)%", color: color)
            }
            
        default:
            EmptyView()
        }
    }
}

// MARK: - Stat Item Component

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    BatchDataStatsView(bluetoothKit: BluetoothKitViewModel())
        .padding()
} 