import SwiftUI
import BluetoothKit

// MARK: - Simplified Batch Data Collection View

/// ViewModel을 사용한 깔끔한 배치 데이터 수집 뷰
struct SimplifiedBatchDataCollectionView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    @StateObject private var viewModel: BatchDataConfigurationViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    // 주로 사용하는 센서들
    private let mainSensors: [SensorType] = [.eeg, .ppg, .accelerometer]
    
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
        .alert("기록 중 센서 변경", isPresented: $viewModel.showRecordingChangeWarning) {
            Button("기록 중지 후 변경", role: .destructive) {
                viewModel.confirmSensorChangeWithRecordingStop()
            }
            Button("취소", role: .cancel) {
                viewModel.cancelSensorChange()
            }
        } message: {
            Text("기록 중에는 센서 설정을 변경할 수 없습니다.\n기록을 중지하고 센서를 변경하시겠습니까?")
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
            
            ForEach(mainSensors, id: \.self) { sensor in
                sensorSampleCountRow(for: sensor)
            }
        }
    }
    
    private var durationConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("센서별 수집 시간")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ForEach(mainSensors, id: \.self) { sensor in
                sensorDurationRow(for: sensor)
            }
        }
    }
    
    private func sensorSampleCountRow(for sensor: SensorType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(sensor.emoji) \(sensor.displayName)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(colorForSensor(sensor))
            
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
    
    private func sensorDurationRow(for sensor: SensorType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(sensor.emoji) \(sensor.displayName)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(colorForSensor(sensor))
            
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
                ForEach(mainSensors, id: \.self) { sensor in
                    sensorToggleButton(for: sensor)
                }
            }
        }
    }
    
    private func sensorToggleButton(for sensor: SensorType) -> some View {
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
                
                Text(sensor.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedSensors.contains(sensor) ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var controlButtonsSection: some View {
        VStack(spacing: 12) {
            // 설정 컨트롤
            HStack(spacing: 12) {
                if viewModel.isConfigured {
                    Button("설정 해제") {
                        viewModel.removeConfiguration()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("설정 적용") {
                        viewModel.applyInitialConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedSensors.isEmpty)
                }
                
                Spacer()
                
                if viewModel.showValidationError {
                    Text(viewModel.validationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // 기록 컨트롤 (설정이 완료된 경우에만 표시)
            if viewModel.isConfigured {
                Divider()
                
                HStack(spacing: 12) {
                    Button(bluetoothKit.isRecording ? "기록 중지" : "기록 시작") {
                        if bluetoothKit.isRecording {
                            bluetoothKit.stopRecording()
                        } else {
                            bluetoothKit.startRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bluetoothKit.isRecording ? .red : .green)
                    .frame(maxWidth: .infinity)
                    
                    if bluetoothKit.isRecording {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "record.circle.fill")
                                    .foregroundColor(.red)
                                    .symbolEffect(.pulse)
                                Text("기록 중")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            Text("선택된 센서 데이터 저장 중")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !bluetoothKit.isRecording && viewModel.isConfigured {
                    Text("💡 센서 설정 완료. 기록 시작 버튼을 눌러 데이터를 저장하세요.")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForSensor(_ sensor: SensorType) -> Color {
        switch sensor.color {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        default: return .primary
        }
    }
    
    /// ViewModel의 기본값을 사용하여 중복 제거
    private func defaultSampleCount(for sensor: SensorType) -> Int {
        return viewModel.getSampleCount(for: sensor)
    }
    
    /// Generic한 바인딩을 생성하여 switch문 중복 제거
    private func sampleCountBinding(for sensor: SensorType) -> Binding<String> {
        return Binding<String>(
            get: { 
                self.viewModel.getSampleCountText(for: sensor)
            },
            set: { newValue in
                self.viewModel.setSampleCountText(newValue, for: sensor)
            }
        )
    }
    
    /// Generic한 바인딩을 생성하여 switch문 중복 제거
    private func durationBinding(for sensor: SensorType) -> Binding<String> {
        return Binding<String>(
            get: { 
                self.viewModel.getDurationText(for: sensor)
            },
            set: { newValue in
                self.viewModel.setDurationText(newValue, for: sensor)
            }
        )
    }
}

#Preview {
    SimplifiedBatchDataCollectionView(bluetoothKit: BluetoothKit())
} 