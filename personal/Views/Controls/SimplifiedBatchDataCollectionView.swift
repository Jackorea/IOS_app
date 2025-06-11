import SwiftUI
import BluetoothKit

// MARK: - Simplified Batch Data Collection View

/// ViewModel을 사용한 깔끔한 배치 데이터 수집 뷰
struct SimplifiedBatchDataCollectionView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    @StateObject private var viewModel: BatchDataConfigurationViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
        self._viewModel = StateObject(wrappedValue: BatchDataConfigurationViewModel(bluetoothKit: bluetoothKit))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            headerView
            
            // 수집 모드 선택
            collectionModeSection
            
            // 수집 설정
            configurationSection
            
            // 센서 선택
            sensorSelectionSection
            
            // 컨트롤 버튼
            controlButtonsSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onTapGesture {
            isTextFieldFocused = false
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Image(systemName: "square.stack.3d.down.right.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            Text("데이터 수집 설정")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            if bluetoothKit.isRecording {
                Image(systemName: "record.circle.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse)
            }
        }
    }
    
    private var collectionModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("수집 모드")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Picker("수집 모드", selection: $viewModel.selectedCollectionMode) {
                ForEach(BatchDataConfigurationViewModel.CollectionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.selectedCollectionMode) { newMode in
                viewModel.updateCollectionMode(newMode)
            }
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.selectedCollectionMode == .sampleCount {
                sampleCountConfiguration
            } else {
                durationConfiguration
            }
        }
    }
    
    private var sampleCountConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("센서별 목표 샘플 수")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(BatchDataConfigurationViewModel.SensorTypeOption.allCases, id: \.self) { sensor in
                sensorSampleCountRow(for: sensor)
            }
        }
    }
    
    private var durationConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("센서별 수집 시간")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(BatchDataConfigurationViewModel.SensorTypeOption.allCases, id: \.self) { sensor in
                sensorDurationRow(for: sensor)
            }
        }
    }
    
    private func sensorSampleCountRow(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sensorIcon(for: sensor) + " " + sensor.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(sensorColor(for: sensor))
            
            HStack {
                TextField("예: \(defaultSampleCount(for: sensor))", text: sampleCountBinding(for: sensor))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .focused($isTextFieldFocused)
                    .onChange(of: sampleCountBinding(for: sensor).wrappedValue) { newValue in
                        _ = viewModel.validateSampleCount(newValue, for: sensor)
                    }
                
                Text("샘플")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func sensorDurationRow(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sensorIcon(for: sensor) + " " + sensor.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(sensorColor(for: sensor))
            
            HStack {
                TextField("예: 1", text: durationBinding(for: sensor))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .focused($isTextFieldFocused)
                    .onChange(of: durationBinding(for: sensor).wrappedValue) { newValue in
                        _ = viewModel.validateDuration(newValue, for: sensor)
                    }
                
                Text("초")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var sensorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("수집할 센서")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(BatchDataConfigurationViewModel.SensorTypeOption.allCases, id: \.self) { sensor in
                    sensorToggleButton(for: sensor)
                }
            }
        }
    }
    
    private func sensorToggleButton(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> some View {
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
                    .foregroundColor(viewModel.selectedSensors.contains(sensor) ? .green : .gray)
                
                Text(sensor.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedSensors.contains(sensor) ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.selectedSensors.contains(sensor) ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var controlButtonsSection: some View {
        VStack(spacing: 12) {
            if viewModel.isConfigured {
                HStack(spacing: 12) {
                    Button("전체 해제") {
                        viewModel.removeConfiguration()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
                    
                    Button(bluetoothKit.isRecording ? "수집 중지" : "수집 시작") {
                        if bluetoothKit.isRecording {
                            bluetoothKit.stopRecording()
                        } else {
                            bluetoothKit.startRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bluetoothKit.isRecording ? .red : .green)
                    .frame(maxWidth: .infinity)
                }
                
                Text("💡 센서 선택을 변경하면 자동으로 적용됩니다")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            } else {
                Button("설정 적용") {
                    viewModel.applyInitialConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
                .disabled(viewModel.selectedSensors.isEmpty || !bluetoothKit.isConnected)
                
                Text("센서를 선택하고 설정 적용을 눌러주세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func sensorIcon(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> String {
        switch sensor {
        case .eeg: return "🧠"
        case .ppg: return "❤️"
        case .accelerometer: return "🏃"
        }
    }
    
    private func sensorColor(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> Color {
        switch sensor {
        case .eeg: return .blue
        case .ppg: return .red
        case .accelerometer: return .green
        }
    }
    
    private func defaultSampleCount(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> Int {
        switch sensor {
        case .eeg: return 250
        case .ppg: return 50
        case .accelerometer: return 30
        }
    }
    
    private func sampleCountBinding(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> Binding<String> {
        switch sensor {
        case .eeg: return $viewModel.eegSampleCountText
        case .ppg: return $viewModel.ppgSampleCountText
        case .accelerometer: return $viewModel.accelerometerSampleCountText
        }
    }
    
    private func durationBinding(for sensor: BatchDataConfigurationViewModel.SensorTypeOption) -> Binding<String> {
        switch sensor {
        case .eeg: return $viewModel.eegDurationText
        case .ppg: return $viewModel.ppgDurationText
        case .accelerometer: return $viewModel.accelerometerDurationText
        }
    }
}

#Preview {
    SimplifiedBatchDataCollectionView(bluetoothKit: BluetoothKit())
        .padding()
} 