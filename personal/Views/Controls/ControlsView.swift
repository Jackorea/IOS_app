import SwiftUI
import BluetoothKit

// MARK: - Controls View

struct ControlsView: View {
    @ObservedObject var bluetoothViewModel: BluetoothKitViewModel
    @StateObject private var batchConfigViewModel: BatchDataConfigurationViewModel
    @State private var consoleLogger: BatchDataConsoleLogger = BatchDataConsoleLogger()
    
    init(bluetoothViewModel: BluetoothKitViewModel) {
        self.bluetoothViewModel = bluetoothViewModel
        self._batchConfigViewModel = StateObject(wrappedValue: BatchDataConfigurationViewModel(bluetoothKit: bluetoothViewModel.bluetoothKit))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("디바이스 컨트롤")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Divider()
            
            VStack(spacing: 12) {
                // 연결 버튼
                Button(action: {
                    if bluetoothViewModel.isConnected {
                        bluetoothViewModel.disconnect()
                    } else {
                        bluetoothViewModel.startScanning()
                    }
                }) {
                    HStack {
                        Image(systemName: bluetoothViewModel.isConnected ? "xmark.circle.fill" : "magnifyingglass.circle.fill")
                        Text(bluetoothViewModel.isConnected ? "연결 해제" : "스캔 시작")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bluetoothViewModel.isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // 모니터링 버튼 (새로 추가)
                Button(action: {
                    if batchConfigViewModel.isConfigured {
                        stopMonitoring()
                    } else {
                        startMonitoring()
                    }
                }) {
                    HStack {
                        Image(systemName: batchConfigViewModel.isConfigured ? "stop.circle.fill" : "play.circle.fill")
                        Text(batchConfigViewModel.isConfigured ? "모니터링 중지" : "모니터링 시작")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(batchConfigViewModel.isConfigured ? Color.orange : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!bluetoothViewModel.isConnected)
                
                // 기록 버튼
                Button(action: {
                    if bluetoothViewModel.isRecording {
                        bluetoothViewModel.stopRecording()
                    } else {
                        bluetoothViewModel.startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: bluetoothViewModel.isRecording ? "stop.circle.fill" : "record.circle.fill")
                        Text(bluetoothViewModel.isRecording ? "기록 중지" : "기록 시작")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bluetoothViewModel.isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!bluetoothViewModel.isConnected)
                
                // 모니터링 중일 때 센서 선택 및 상태 표시
                if batchConfigViewModel.isConfigured {
                    monitoringStatusSection
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
    
    // MARK: - Monitoring Control Methods
    
    private func startMonitoring() {
        // 기본 센서 선택 (EEG, PPG, 가속도계)
        let defaultSensors: Set<SensorType> = [.eeg, .ppg, .accelerometer]
        consoleLogger.updateSelectedSensors(defaultSensors)
        bluetoothViewModel.batchDataDelegate = consoleLogger
        batchConfigViewModel.updateSensorSelection(defaultSensors)
        batchConfigViewModel.startMonitoring()
        
        print("🎯 모니터링 시작 - 콘솔 출력 활성화")
        print("📊 선택된 센서: \(defaultSensors.map { $0.displayName }.joined(separator: ", "))")
    }
    
    private func stopMonitoring() {
        batchConfigViewModel.stopMonitoring()
        bluetoothViewModel.batchDataDelegate = nil
        consoleLogger.updateSelectedSensors(Set<SensorType>())
        
        print("⏹️ 모니터링 중지 - 콘솔 출력 비활성화")
    }
    
    // MARK: - Monitoring Status Section
    
    @ViewBuilder
    private var monitoringStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tv")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("콘솔 모니터링 활성")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            // 활성 센서 표시
            HStack {
                ForEach(Array(batchConfigViewModel.selectedSensors), id: \.self) { sensor in
                    sensorIndicator(for: sensor)
                }
                Spacer()
            }
            
            // 센서 선택 변경 버튼
            sensorSelectionButtons
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    private func sensorIndicator(for sensor: SensorType) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(sensorColor(for: sensor))
                .frame(width: 8, height: 8)
                .symbolEffect(.pulse, isActive: hasRecentData(for: sensor))
            
            Text(sensor.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(sensorColor(for: sensor).opacity(0.2))
        )
    }
    
    private var sensorSelectionButtons: some View {
        HStack(spacing: 8) {
            ForEach([SensorType.eeg, .ppg, .accelerometer, .battery], id: \.self) { sensor in
                Button(action: {
                    toggleSensor(sensor)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: batchConfigViewModel.selectedSensors.contains(sensor) ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                        Text(sensor.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(batchConfigViewModel.selectedSensors.contains(sensor) ? sensorColor(for: sensor) : Color.gray)
                    )
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleSensor(_ sensor: SensorType) {
        var newSelection = batchConfigViewModel.selectedSensors
        if newSelection.contains(sensor) {
            newSelection.remove(sensor)
        } else {
            newSelection.insert(sensor)
        }
        
        // 콘솔 로거에도 즉시 반영
        consoleLogger.updateSelectedSensors(newSelection)
        batchConfigViewModel.updateSensorSelection(newSelection)
        
        print("🔄 센서 선택 변경: \(newSelection.map { $0.displayName }.joined(separator: ", "))")
    }
    
    private func sensorColor(for sensor: SensorType) -> Color {
        switch sensor {
        case .eeg: return .purple
        case .ppg: return .red
        case .accelerometer: return .blue
        case .battery: return .green
        }
    }
    
    private func hasRecentData(for sensor: SensorType) -> Bool {
        switch sensor {
        case .eeg: return bluetoothViewModel.latestEEGReading != nil
        case .ppg: return bluetoothViewModel.latestPPGReading != nil
        case .accelerometer: return bluetoothViewModel.latestAccelerometerReading != nil
        case .battery: return bluetoothViewModel.latestBatteryReading != nil
        }
    }
}

#Preview {
    ControlsView(bluetoothViewModel: BluetoothKitViewModel())
} 