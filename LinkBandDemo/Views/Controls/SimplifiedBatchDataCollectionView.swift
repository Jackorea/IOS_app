import SwiftUI

// MARK: - Simplified Batch Data Collection View

/// ViewModel을 사용한 깔끔한 배치 데이터 수집 뷰
struct SimplifiedBatchDataCollectionView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    @StateObject private var viewModel: BatchDataConfigurationViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var showStopMonitoringAlert = false
    
    // 개별 텍스트 필드 포커스 상태 추적
    @FocusState private var focusedSampleCountField: SensorKind?
    @FocusState private var focusedSecondsField: SensorKind?
    @FocusState private var focusedMinutesField: SensorKind?
    
    // 주로 사용하는 센서들
    private let mainSensors: [SensorKind] = [.eeg, .ppg, .accelerometer]
    
    init(bluetoothKit: BluetoothKitViewModel) {
        self.bluetoothKit = bluetoothKit
        self._viewModel = StateObject(wrappedValue: bluetoothKit.createBatchDataConfigurationViewModel())
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
            // 모든 포커스 해제
            isTextFieldFocused = false
            focusedSampleCountField = nil
            focusedSecondsField = nil
            focusedMinutesField = nil
        }
        .onChange(of: isTextFieldFocused) { isFocused in
            // 포커스가 해제될 때 모든 텍스트 필드 검사하고 빈 값이면 기본값으로 복원
            if !isFocused {
                restoreEmptyFieldsToDefaults()
            }
        }
        .onChange(of: focusedSampleCountField) { focusedSensor in
            // 샘플 수 텍스트 필드의 포커스가 변경될 때
            if focusedSensor == nil {
                // 포커스가 해제되면 모든 샘플 수 필드 검증
                for sensor in mainSensors {
                    let currentValue = viewModel.getSampleCountText(for: sensor)
                    validateAndFixSampleCount(currentValue, for: sensor)
                }
            }
        }
        .onChange(of: focusedSecondsField) { focusedSensor in
            // 시간(초) 텍스트 필드의 포커스가 변경될 때
            if focusedSensor == nil {
                // 포커스가 해제되면 모든 시간(초) 필드 검증
                for sensor in mainSensors {
                    let currentValue = viewModel.getSecondsText(for: sensor)
                    validateAndFixSeconds(currentValue, for: sensor)
                }
            }
        }
        .onChange(of: focusedMinutesField) { focusedSensor in
            // 분 텍스트 필드의 포커스가 변경될 때
            if focusedSensor == nil {
                // 포커스가 해제되면 모든 분 필드 검증
                for sensor in mainSensors {
                    let currentValue = viewModel.getMinutesText(for: sensor)
                    validateAndFixMinutes(currentValue, for: sensor)
                }
            }
        }
        .onAppear {
            // 뷰가 나타날 때 모든 텍스트 필드가 기본값으로 초기화되었는지 확인
            ensureAllFieldsHaveValues()
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
        .onChange(of: bluetoothKit.accelerometerMode) { newMode in
            // 실시간 모니터링 중에 가속도계 모드가 변경되면 콘솔 출력에 즉시 반영
            viewModel.updateAccelerometerMode(newMode)
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
                ForEach(CollectionModeKind.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .disabled(viewModel.isMonitoringActive)
            .onChange(of: viewModel.selectedCollectionMode) { newMode in
                // 모드가 변경되면 ViewModel에 전달
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
                Text(viewModel.selectedCollectionMode == .seconds ? "센서별 수집 시간 (초)" : "센서별 수집 시간 (분)")
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
                if viewModel.selectedCollectionMode == .seconds {
                    sensorSecondsRow(for: sensor)
                } else {
                    sensorMinutesRow(for: sensor)
                }
            }
        }
    }
    
    private func sensorSampleCountRow(for sensor: SensorKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(sensor.emoji) \(sensor.displayName)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(colorForSensor(sensor))
            
            HStack {
                TextField("예: \(defaultSampleCount(for: sensor))", text: sampleCountBinding(for: sensor))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .focused($focusedSampleCountField, equals: sensor)
                    .disabled(viewModel.isMonitoringActive || bluetoothKit.isRecording)
                    .opacity(viewModel.isMonitoringActive || bluetoothKit.isRecording ? 0.6 : 1.0)
                    .onTapGesture {
                        if viewModel.isMonitoringActive || bluetoothKit.isRecording {
                            // 텍스트 필드 비활성화 상태에서는 포커스 해제만
                            focusedSampleCountField = nil
                        }
                    }
                    .onChange(of: sampleCountBinding(for: sensor).wrappedValue) { newValue in
                        validateAndFixSampleCount(newValue, for: sensor)
                    }
                    .onSubmit {
                        // 엔터 키를 눌렀을 때도 검증
                        let currentValue = viewModel.getSampleCountText(for: sensor)
                        validateAndFixSampleCount(currentValue, for: sensor)
                        focusedSampleCountField = nil
                    }
                
                Text("샘플")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func sensorSecondsRow(for sensor: SensorKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(sensor.emoji) \(sensor.displayName)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(colorForSensor(sensor))
            
            HStack {
                TextField("예: 1", text: durationBinding(for: sensor))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .focused($focusedSecondsField, equals: sensor)
                    .disabled(viewModel.isMonitoringActive || bluetoothKit.isRecording)
                    .opacity(viewModel.isMonitoringActive || bluetoothKit.isRecording ? 0.6 : 1.0)
                    .onTapGesture {
                        if viewModel.isMonitoringActive || bluetoothKit.isRecording {
                            // 텍스트 필드 비활성화 상태에서는 포커스 해제만
                            focusedSecondsField = nil
                        }
                    }
                    .onChange(of: durationBinding(for: sensor).wrappedValue) { newValue in
                        validateAndFixSeconds(newValue, for: sensor)
                    }
                    .onSubmit {
                        // 엔터 키를 눌렀을 때도 검증
                        let currentValue = viewModel.getSecondsText(for: sensor)
                        validateAndFixSeconds(currentValue, for: sensor)
                        focusedSecondsField = nil
                    }
                
                Text("초")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func sensorMinutesRow(for sensor: SensorKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(sensor.emoji) \(sensor.displayName)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(colorForSensor(sensor))
            
            HStack {
                TextField("예: 1", text: minutesBinding(for: sensor))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .focused($focusedMinutesField, equals: sensor)
                    .disabled(viewModel.isMonitoringActive || bluetoothKit.isRecording)
                    .opacity(viewModel.isMonitoringActive || bluetoothKit.isRecording ? 0.6 : 1.0)
                    .onTapGesture {
                        if viewModel.isMonitoringActive || bluetoothKit.isRecording {
                            // 텍스트 필드 비활성화 상태에서는 포커스 해제만
                            focusedMinutesField = nil
                        }
                    }
                    .onChange(of: minutesBinding(for: sensor).wrappedValue) { newValue in
                        validateAndFixMinutes(newValue, for: sensor)
                    }
                    .onSubmit {
                        // 엔터 키를 눌렀을 때도 검증
                        let currentValue = viewModel.getMinutesText(for: sensor)
                        validateAndFixMinutes(currentValue, for: sensor)
                        focusedMinutesField = nil
                    }
                
                Text("분")
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
                        isSelected: viewModel.selectedSensors.contains(sensor),
                        isDisabled: viewModel.isMonitoringActive
                    ) {
                        toggleSensorSelection(sensor)
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
                        // 기록 중이면 경고 팝업 표시, 아니면 바로 중지
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
    
    private func colorForSensor(_ sensor: SensorKind) -> Color {
        switch sensor.color {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        default: return .primary
        }
    }
    
    /// ViewModel의 기본값을 사용하여 중복 제거
    private func defaultSampleCount(for sensor: SensorKind) -> Int {
        switch sensor {
        case .eeg:
            return 250
        case .ppg:
            return 50
        case .accelerometer:
            return 30
        case .battery:
            return 1
        }
    }
    
    /// Generic한 바인딩을 생성하여 switch문 중복 제거
    private func sampleCountBinding(for sensor: SensorKind) -> Binding<String> {
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
    private func durationBinding(for sensor: SensorKind) -> Binding<String> {
        return Binding<String>(
            get: { 
                self.viewModel.getSecondsText(for: sensor)
            },
            set: { newValue in
                self.viewModel.setSecondsText(newValue, for: sensor)
            }
        )
    }
    
    /// 분단위 바인딩을 생성합니다.
    private func minutesBinding(for sensor: SensorKind) -> Binding<String> {
        return Binding<String>(
            get: { 
                self.viewModel.getMinutesText(for: sensor)
            },
            set: { newValue in
                self.viewModel.setMinutesText(newValue, for: sensor)
            }
        )
    }
    
    /// 샘플 수 실시간 검증 및 자동 복원
    private func validateAndFixSampleCount(_ newValue: String, for sensor: SensorKind) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 값이면 즉시 기본값으로 복원
        if trimmedValue.isEmpty {
            let defaultValue = defaultSampleCount(for: sensor)
            viewModel.setSampleCountText("\(defaultValue)", for: sensor)
            return
        }
        
        // 숫자가 아닌 문자가 포함되어 있으면 제거
        let numbersOnly = trimmedValue.filter { $0.isNumber }
        if numbersOnly != trimmedValue {
            // 숫자가 없으면 기본값으로 복원
            if numbersOnly.isEmpty {
                let defaultValue = defaultSampleCount(for: sensor)
                viewModel.setSampleCountText("\(defaultValue)", for: sensor)
            } else {
                viewModel.setSampleCountText(numbersOnly, for: sensor)
            }
            return
        }
        
        // 0으로만 이루어져 있으면 기본값으로 복원
        if numbersOnly.allSatisfy({ $0 == "0" }) {
            let defaultValue = defaultSampleCount(for: sensor)
            viewModel.setSampleCountText("\(defaultValue)", for: sensor)
            return
        }
        
        // 유효성 검사 실행
        _ = viewModel.validateSampleCount(newValue, for: sensor)
    }
    
    /// 시간(초) 실시간 검증 및 자동 복원
    private func validateAndFixSeconds(_ newValue: String, for sensor: SensorKind) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 값이면 즉시 기본값으로 복원
        if trimmedValue.isEmpty {
            let defaultValue = sensor == .battery ? 60 : 1
            viewModel.setSecondsText("\(defaultValue)", for: sensor)
            return
        }
        
        // 숫자가 아닌 문자가 포함되어 있으면 제거
        let numbersOnly = trimmedValue.filter { $0.isNumber }
        if numbersOnly != trimmedValue {
            // 숫자가 없으면 기본값으로 복원
            if numbersOnly.isEmpty {
                let defaultValue = sensor == .battery ? 60 : 1
                viewModel.setSecondsText("\(defaultValue)", for: sensor)
            } else {
                viewModel.setSecondsText(numbersOnly, for: sensor)
            }
            return
        }
        
        // 0으로만 이루어져 있으면 기본값으로 복원
        if numbersOnly.allSatisfy({ $0 == "0" }) {
            let defaultValue = sensor == .battery ? 60 : 1
            viewModel.setSecondsText("\(defaultValue)", for: sensor)
            return
        }
        
        // 유효성 검사 실행
        _ = viewModel.validateSeconds(newValue, for: sensor)
    }
    
    /// 분 실시간 검증 및 자동 복원
    private func validateAndFixMinutes(_ newValue: String, for sensor: SensorKind) {
        let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 빈 값이면 즉시 기본값으로 복원
        if trimmedValue.isEmpty {
            viewModel.setMinutesText("1", for: sensor)
            return
        }
        
        // 숫자가 아닌 문자가 포함되어 있으면 제거
        let numbersOnly = trimmedValue.filter { $0.isNumber }
        if numbersOnly != trimmedValue {
            // 숫자가 없으면 기본값으로 복원
            if numbersOnly.isEmpty {
                viewModel.setMinutesText("1", for: sensor)
            } else {
                viewModel.setMinutesText(numbersOnly, for: sensor)
            }
            return
        }
        
        // 0으로만 이루어져 있으면 기본값으로 복원
        if numbersOnly.allSatisfy({ $0 == "0" }) {
            viewModel.setMinutesText("1", for: sensor)
            return
        }
        
        // 유효성 검사 실행
        _ = viewModel.validateMinutes(newValue, for: sensor)
    }
    
    private func restoreEmptyFieldsToDefaults() {
        for sensor in mainSensors {
            // 샘플 수 텍스트 필드 확인
            let sampleCountText = viewModel.getSampleCountText(for: sensor)
            if sampleCountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.setSampleCountText("\(defaultSampleCount(for: sensor))", for: sensor)
            }
            
            // 시간(초) 텍스트 필드 확인
            let secondsText = viewModel.getSecondsText(for: sensor)
            if secondsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let defaultSeconds = sensor == .battery ? 60 : 1
                viewModel.setSecondsText("\(defaultSeconds)", for: sensor)
            }
            
            // 분 텍스트 필드 확인
            let minutesText = viewModel.getMinutesText(for: sensor)
            if minutesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.setMinutesText("1", for: sensor)
            }
        }
    }
    
    private func toggleSensorSelection(_ sensor: SensorKind) {
        // 모니터링 중이 아닐 때만 센서 선택 변경 가능
        guard !viewModel.isMonitoringActive else { return }
        
        // 센서 선택/해제 토글
        var newSelection = viewModel.selectedSensors
        if newSelection.contains(sensor) {
            newSelection.remove(sensor)
        } else {
            newSelection.insert(sensor)
        }
        viewModel.updateSensorSelection(newSelection)
    }
    
    private func ensureAllFieldsHaveValues() {
        for sensor in mainSensors {
            // 샘플 수 텍스트 필드 확인
            let sampleCountText = viewModel.getSampleCountText(for: sensor)
            if sampleCountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.setSampleCountText("\(defaultSampleCount(for: sensor))", for: sensor)
            }
            
            // 시간(초) 텍스트 필드 확인
            let secondsText = viewModel.getSecondsText(for: sensor)
            if secondsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let defaultSeconds = sensor == .battery ? 60 : 1
                viewModel.setSecondsText("\(defaultSeconds)", for: sensor)
            }
            
            // 분 텍스트 필드 확인
            let minutesText = viewModel.getMinutesText(for: sensor)
            if minutesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.setMinutesText("1", for: sensor)
            }
        }
    }
}

// MARK: - Helper Views

private struct SensorToggleButton: View {
    let sensor: SensorKind
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
    SimplifiedBatchDataCollectionView(bluetoothKit: BluetoothKitViewModel())
} 