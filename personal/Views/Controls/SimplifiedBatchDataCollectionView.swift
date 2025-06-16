import SwiftUI
import BluetoothKit

// MARK: - Simplified Batch Data Collection View

/// ViewModel을 사용한 깔끔한 배치 데이터 수집 뷰
struct SimplifiedBatchDataCollectionView: View {
    @ObservedObject var bluetoothViewModel: BluetoothKitViewModel
    @StateObject private var viewModel: BatchDataConfigurationViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var showStopMonitoringAlert = false
    
    // 주로 사용하는 센서들
    private let mainSensors: [SensorType] = [.eeg, .ppg, .accelerometer]
    
    init(bluetoothViewModel: BluetoothKitViewModel) {
        self.bluetoothViewModel = bluetoothViewModel
        self._viewModel = StateObject(wrappedValue: BatchDataConfigurationViewModel(bluetoothKit: bluetoothViewModel.bluetoothKit))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("배치 데이터 수집")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                configurationToggle
            }
            
            Divider()
            
            if viewModel.isConfigured {
                configuredContent
            } else {
                unconfiguredContent
            }
        }
        .padding()
        .background(cardBackground)
        .alert("기록 중 설정 변경", isPresented: $viewModel.showRecordingChangeWarning) {
            alertButtons
        } message: {
            Text("현재 기록 중입니다. 설정을 변경하려면 기록을 중지해야 합니다.")
        }
    }
    
    // MARK: - View Components
    
    private var configurationToggle: some View {
        Button(action: {
            if viewModel.isConfigured {
                viewModel.stopMonitoring()
            } else {
                viewModel.startMonitoring()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isConfigured ? "stop.circle.fill" : "play.circle.fill")
                    .font(.caption)
                Text(viewModel.isConfigured ? "중지" : "시작")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.isConfigured ? Color.red : Color.green)
            )
            .foregroundColor(.white)
        }
        .disabled(!bluetoothViewModel.isConnected)
    }
    
    @ViewBuilder
    private var configuredContent: some View {
        VStack(spacing: 12) {
            // 선택된 센서 표시
            sensorSelectionDisplay
            
            // 수집 모드와 설정 표시
            collectionModeDisplay
            
            // 배치 수집 통계 (실제 데이터가 들어오면 표시)
            if bluetoothViewModel.latestEEGReading != nil ||
               bluetoothViewModel.latestPPGReading != nil ||
               bluetoothViewModel.latestAccelerometerReading != nil {
                realTimeDataIndicator
            }
        }
    }
    
    @ViewBuilder
    private var unconfiguredContent: some View {
        VStack(spacing: 16) {
            // 센서 선택
            sensorSelectionSection
            
            // 수집 모드 선택
            collectionModeSection
            
            // 각 센서별 설정
            ForEach(Array(SensorType.allCases.filter { viewModel.selectedSensors.contains($0) }), id: \.self) { sensor in
                sensorConfigurationSection(for: sensor)
            }
        }
    }
    
    private var sensorSelectionDisplay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("활성 센서")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(Array(viewModel.selectedSensors), id: \.self) { sensor in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(sensorColor(for: sensor))
                            .frame(width: 8, height: 8)
                        
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
                Spacer()
            }
        }
    }
    
    private var collectionModeDisplay: some View {
        HStack {
            Text("수집 모드")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(viewModel.selectedCollectionMode.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.2))
                )
        }
    }
    
    private var realTimeDataIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("실시간 데이터")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                ForEach(Array(viewModel.selectedSensors), id: \.self) { sensor in
                    let hasData = hasRecentData(for: sensor)
                    
                    VStack(spacing: 4) {
                        Circle()
                            .fill(hasData ? sensorColor(for: sensor) : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .symbolEffect(.pulse, isActive: hasData)
                        
                        Text(sensor.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(hasData ? sensorColor(for: sensor) : .secondary)
                    }
                }
                Spacer()
            }
        }
    }
    
    private var sensorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("센서 선택")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(SensorType.allCases, id: \.self) { sensor in
                    sensorToggle(for: sensor)
                }
            }
        }
    }
    
    private func sensorToggle(for sensor: SensorType) -> some View {
        Button(action: {
            var newSelection = viewModel.selectedSensors
            if newSelection.contains(sensor) {
                newSelection.remove(sensor)
            } else {
                newSelection.insert(sensor)
            }
            viewModel.updateSensorSelection(newSelection)
        }) {
            HStack {
                Image(systemName: viewModel.selectedSensors.contains(sensor) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(viewModel.selectedSensors.contains(sensor) ? sensorColor(for: sensor) : .gray)
                
                Text(sensor.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedSensors.contains(sensor) ? sensorColor(for: sensor).opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var collectionModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("수집 모드")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("", selection: $viewModel.selectedCollectionMode) {
                ForEach(BatchDataConfigurationViewModel.CollectionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private func sensorConfigurationSection(for sensor: SensorType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: sensorIcon(for: sensor))
                    .foregroundColor(sensorColor(for: sensor))
                
                Text(sensor.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            switch viewModel.selectedCollectionMode {
            case .sampleCount:
                sampleCountConfiguration(for: sensor)
            case .duration:
                durationConfiguration(for: sensor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(sensorColor(for: sensor).opacity(0.1))
        )
    }
    
    private func sampleCountConfiguration(for sensor: SensorType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("샘플 수")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(viewModel.getSampleCount(for: sensor))개")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            let expectedTime = viewModel.getExpectedTime(for: sensor, sampleCount: viewModel.getSampleCount(for: sensor))
            Text("예상 시간: \(String(format: "%.1f", expectedTime))초")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func durationConfiguration(for sensor: SensorType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("시간")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(viewModel.getDuration(for: sensor))초")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            let expectedSamples = viewModel.getExpectedSamples(for: sensor, duration: viewModel.getDuration(for: sensor))
            Text("예상 샘플: \(expectedSamples)개")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.1))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var alertButtons: some View {
        Group {
            Button("기록 중지 후 변경") {
                viewModel.confirmSensorChangeWithRecordingStop()
            }
            
            Button("취소", role: .cancel) {
                viewModel.cancelSensorChange()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func sensorColor(for sensor: SensorType) -> Color {
        switch sensor {
        case .eeg: return .purple
        case .ppg: return .red
        case .accelerometer: return .blue
        case .battery: return .green
        }
    }
    
    private func sensorIcon(for sensor: SensorType) -> String {
        switch sensor {
        case .eeg: return "brain.head.profile"
        case .ppg: return "heart.fill"
        case .accelerometer: return "move.3d"
        case .battery: return "battery.75"
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
    SimplifiedBatchDataCollectionView(bluetoothViewModel: BluetoothKitViewModel())
} 