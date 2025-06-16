import SwiftUI
import BluetoothKit

// MARK: - Simplified Batch Data Collection View

/// ViewModel을 사용한 깔끔한 배치 데이터 수집 뷰
struct SimplifiedBatchDataCollectionView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    @StateObject private var viewModel: BatchDataConfigurationViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var showStopMonitoringAlert = false
    
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
            if viewModel.selectedCollectionMode == .sampleCount {
                sampleCountConfiguration
            } else {
                durationConfiguration
            }
            
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
        .alert("모니터링 중지 확인", isPresented: $showStopMonitoringAlert) {
            Button("기록 및 모니터링 중지", role: .destructive) {
                // 기록 중지 후 모니터링 중지
                if bluetoothKit.isRecording {
                    bluetoothKit.stopRecording()
                }
                viewModel.stopMonitoring()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("데이터 기록이 진행 중입니다.\n모니터링을 중지하면 기록도 함께 중지됩니다.")
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
                ForEach(BatchDataConfigurationManager.CollectionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .disabled(viewModel.isMonitoringActive)
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
            HStack {
                Text("센서별 목표 샘플 수")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if viewModel.isMonitoringActive || bluetoothKit.isRecording {
                    HStack(spacing: 4) {
                        Image(systemName: bluetoothKit.isRecording ? "record.circle.fill" : "eye.fill")
                            .foregroundColor(bluetoothKit.isRecording ? .red : .orange)
                            .font(.caption)
                        Text(bluetoothKit.isRecording ? "기록 중" : "모니터링 중")
                            .font(.caption)
                            .foregroundColor(bluetoothKit.isRecording ? .red : .orange)
                            .fontWeight(.medium)
                    }
                }
            }
            
            ForEach(mainSensors, id: \.self) { sensor in
                sensorSampleCountRow(for: sensor)
            }
        }
    }
    
    private var durationConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("센서별 수집 시간")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if viewModel.isMonitoringActive || bluetoothKit.isRecording {
                    HStack(spacing: 4) {
                        Image(systemName: bluetoothKit.isRecording ? "record.circle.fill" : "eye.fill")
                            .foregroundColor(bluetoothKit.isRecording ? .red : .orange)
                            .font(.caption)
                        Text(bluetoothKit.isRecording ? "기록 중" : "모니터링 중")
                            .font(.caption)
                            .foregroundColor(bluetoothKit.isRecording ? .red : .orange)
                            .fontWeight(.medium)
                    }
                }
            }
            
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
                    .disabled(viewModel.isMonitoringActive || bluetoothKit.isRecording)
                    .opacity(viewModel.isMonitoringActive || bluetoothKit.isRecording ? 0.6 : 1.0)
                    .onTapGesture {
                        if viewModel.isMonitoringActive || bluetoothKit.isRecording {
                            if bluetoothKit.isRecording {
                                viewModel.handleTextFieldEditAttemptDuringRecording()
                            } else {
                                viewModel.showRecordingChangeWarning = true
                            }
                            isTextFieldFocused = false
                        }
                    }
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
                    .disabled(viewModel.isMonitoringActive || bluetoothKit.isRecording)
                    .opacity(viewModel.isMonitoringActive || bluetoothKit.isRecording ? 0.6 : 1.0)
                    .onTapGesture {
                        if viewModel.isMonitoringActive || bluetoothKit.isRecording {
                            if bluetoothKit.isRecording {
                                viewModel.handleTextFieldEditAttemptDuringRecording()
                            } else {
                                viewModel.showRecordingChangeWarning = true
                            }
                            isTextFieldFocused = false
                        }
                    }
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
            Text("센서 선택")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(mainSensors, id: \.self) { sensor in
                    SensorToggleButton(
                        sensor: sensor,
                        isSelected: viewModel.isSensorSelected(sensor),
                        isDisabled: viewModel.isMonitoringActive
                    ) {
                        if viewModel.isMonitoringActive {
                            // 모니터링 중에는 경고 팝업 표시
                            viewModel.updateSensorSelection([sensor])
                        } else {
                            // 모니터링 중이 아닐 때는 즉시 변경
                            var newSelection = viewModel.selectedSensors
                            if viewModel.isSensorSelected(sensor) {
                                newSelection.remove(sensor)
                            } else {
                                newSelection.insert(sensor)
                            }
                            viewModel.updateSensorSelection(newSelection)
                        }
                    }
                }
            }
        }
    }
    
    private var controlButtonsSection: some View {
        VStack(spacing: 12) {
            // 모니터링 컨트롤
            HStack(spacing: 12) {
                if viewModel.isMonitoringActive {
                    Button("모니터링 중지") {
                        // 데이터 기록 중이라면 경고 팝업 표시
                        if bluetoothKit.isRecording {
                            showStopMonitoringAlert = true
                        } else {
                            viewModel.stopMonitoring()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("모니터링 시작") {
                        viewModel.startMonitoring()
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
            
            // 기록 컨트롤 (실질적인 모니터링이 활성화된 경우에만 표시)
            if viewModel.isMonitoringActive {
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
                
                if !bluetoothKit.isRecording && viewModel.isMonitoringActive {
                    Text("💡 센서 모니터링 중. 기록 시작 버튼을 눌러 데이터를 저장하세요.")
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

// MARK: - Helper Views

private struct SensorToggleButton: View {
    let sensor: SensorType
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.system(size: 14))
                
                Text(sensor.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

#Preview {
    SimplifiedBatchDataCollectionView(bluetoothKit: BluetoothKit())
} 