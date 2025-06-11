import SwiftUI
import BluetoothKit

// MARK: - Batch Data Collection View

/// 데이터 수집 설정을 위한 뷰 - 샘플 수와 시간 기반 수집 지원
struct BatchDataCollectionView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    @State private var selectedCollectionMode: CollectionMode = .sampleCount
    
    // 센서별 개별 샘플 수 설정
    @State private var eegSampleCount: Int = 250
    @State private var ppgSampleCount: Int = 50
    @State private var accelerometerSampleCount: Int = 30
    
    // 센서별 개별 시간 설정
    @State private var eegDurationSeconds: Int = 1
    @State private var ppgDurationSeconds: Int = 1
    @State private var accelerometerDurationSeconds: Int = 1
    
    @State private var selectedSensors: Set<SensorTypeOption> = [.eeg, .ppg, .accelerometer]
    @State private var isConfigured = false
    
    // 센서별 개별 텍스트 필드
    @State private var eegSampleCountText: String = "250"
    @State private var ppgSampleCountText: String = "50"
    @State private var accelerometerSampleCountText: String = "30"
    
    @State private var eegDurationText: String = "1"
    @State private var ppgDurationText: String = "1"
    @State private var accelerometerDurationText: String = "1"
    
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""
    @State private var batchDelegate: BatchDataConsoleLogger?
    @FocusState private var isTextFieldFocused: Bool
    
    enum CollectionMode: String, CaseIterable {
        case sampleCount = "샘플 수"
        case duration = "시간 (초)"
    }
    
    enum SensorTypeOption: String, CaseIterable {
        case eeg = "EEG"
        case ppg = "PPG"
        case accelerometer = "ACC"
        
        var sdkType: SensorType {
            switch self {
            case .eeg: return .eeg
            case .ppg: return .ppg
            case .accelerometer: return .accelerometer
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
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
            
            // 수집 모드 선택
            VStack(alignment: .leading, spacing: 12) {
                Text("수집 모드")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Picker("수집 모드", selection: $selectedCollectionMode) {
                    ForEach(CollectionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedCollectionMode) { _ in
                    // 설정이 이미 완료된 상태에서만 자동 적용
                    if isConfigured {
                        applyConfigurationChanges()
                    }
                }
            }
            
            // 수집 설정
            VStack(alignment: .leading, spacing: 12) {
                if selectedCollectionMode == .sampleCount {
                    sampleCountConfiguration
                } else {
                    durationConfiguration
                }
            }
            
            // 센서 선택
            sensorSelectionView
            
            // 설정 상태
            if isConfigured {
                configurationStatusView
            }
            
            // 수집 컨트롤 버튼 (간소화)
            simplifiedControlButtons
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onTapGesture {
            // 화면을 탭하면 키보드 숨기기
            isTextFieldFocused = false
        }
    }
    
    private var sampleCountConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("센서별 목표 샘플 수")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // EEG 설정
            VStack(alignment: .leading, spacing: 8) {
                Text("🧠 EEG")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                HStack {
                    TextField("예: 250", text: $eegSampleCountText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: eegSampleCountText) { newValue in
                            validateAndUpdateSampleCount(newValue, for: .eeg)
                        }
                        .onAppear {
                            eegSampleCountText = "\(eegSampleCount)"
                        }
                    
                    Text("샘플")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // PPG 설정
            VStack(alignment: .leading, spacing: 8) {
                Text("❤️ PPG")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                HStack {
                    TextField("예: 50", text: $ppgSampleCountText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: ppgSampleCountText) { newValue in
                            validateAndUpdateSampleCount(newValue, for: .ppg)
                        }
                        .onAppear {
                            ppgSampleCountText = "\(ppgSampleCount)"
                        }
                    
                    Text("샘플")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 가속도계 설정
            VStack(alignment: .leading, spacing: 8) {
                Text("🏃 ACC")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                HStack {
                    TextField("예: 30", text: $accelerometerSampleCountText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: accelerometerSampleCountText) { newValue in
                            validateAndUpdateSampleCount(newValue, for: .accelerometer)
                        }
                        .onAppear {
                            accelerometerSampleCountText = "\(accelerometerSampleCount)"
                        }
                    
                    Text("샘플")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var durationConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("센서별 수집 시간")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // EEG 설정
            VStack(alignment: .leading, spacing: 8) {
                Text("🧠 EEG")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                HStack {
                    TextField("예: 1", text: $eegDurationText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: eegDurationText) { newValue in
                            validateAndUpdateDuration(newValue, for: .eeg)
                        }
                        .onAppear {
                            eegDurationText = "\(eegDurationSeconds)"
                        }
                    
                    Text("초")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // PPG 설정
            VStack(alignment: .leading, spacing: 8) {
                Text("❤️ PPG")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                HStack {
                    TextField("예: 1", text: $ppgDurationText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: ppgDurationText) { newValue in
                            validateAndUpdateDuration(newValue, for: .ppg)
                        }
                        .onAppear {
                            ppgDurationText = "\(ppgDurationSeconds)"
                        }
                    
                    Text("초")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 가속도계 설정
            VStack(alignment: .leading, spacing: 8) {
                Text("🏃 ACC")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                HStack {
                    TextField("예: 1", text: $accelerometerDurationText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: accelerometerDurationText) { newValue in
                            validateAndUpdateDuration(newValue, for: .accelerometer)
                        }
                        .onAppear {
                            accelerometerDurationText = "\(accelerometerDurationSeconds)"
                        }
                    
                    Text("초")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var sensorSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("수집할 센서")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(SensorTypeOption.allCases, id: \.self) { sensor in
                    sensorToggleButton(for: sensor)
                }
            }
        }
    }
    
    private func sensorToggleButton(for sensor: SensorTypeOption) -> some View {
        Button(action: {
            if selectedSensors.contains(sensor) {
                selectedSensors.remove(sensor)
            } else {
                selectedSensors.insert(sensor)
            }
            // 설정이 이미 완료된 상태에서만 자동 적용
            if isConfigured {
                applyConfigurationChanges()
            }
        }) {
            HStack {
                Image(systemName: selectedSensors.contains(sensor) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedSensors.contains(sensor) ? .green : .gray)
                
                Text(sensor.rawValue)
                    .font(.subheadline)
                        .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSensors.contains(sensor) ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedSensors.contains(sensor) ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var configurationStatusView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("설정 완료")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("센서별 개별 설정")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                if selectedCollectionMode == .sampleCount {
                    HStack {
                        Text("🧠 EEG:")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(eegSampleCount)개 샘플")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack {
                        Text("❤️ PPG:")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("\(ppgSampleCount)개 샘플")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack {
                        Text("🏃 ACC:")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("\(accelerometerSampleCount)개 샘플")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                } else {
                    HStack {
                        Text("🧠 EEG:")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(eegDurationSeconds)초마다")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack {
                        Text("❤️ PPG:")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("\(ppgDurationSeconds)초마다")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack {
                        Text("🏃 ACC:")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("\(accelerometerDurationSeconds)초마다")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
            }
            
            Text("선택된 센서: \(selectedSensors.map { $0.rawValue }.joined(separator: ", "))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var simplifiedControlButtons: some View {
        VStack(spacing: 12) {
            if isConfigured {
                HStack(spacing: 12) {
                    Button("전체 해제") {
                        removeConfiguration()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
                    
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
                }
                
                Text("💡 센서 선택을 변경하면 자동으로 적용됩니다")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            } else {
                Button("설정 적용") {
                    applyInitialConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
                .disabled(selectedSensors.isEmpty || !bluetoothKit.isConnected)
                
                Text("센서를 선택하고 설정 적용을 눌러주세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Configuration Methods
    
    private func applyInitialConfiguration() {
        guard !selectedSensors.isEmpty else { return }
        
        // 배치 데이터 델리게이트 등록
        if batchDelegate == nil {
            batchDelegate = BatchDataConsoleLogger()
            bluetoothKit.batchDataDelegate = batchDelegate
        }
        
        // 선택된 센서를 로거에 업데이트
        let selectedSensorTypes = Set(selectedSensors.map { $0.sdkType })
        batchDelegate?.updateSelectedSensors(selectedSensorTypes)
        
        for sensor in selectedSensors {
            if selectedCollectionMode == .sampleCount {
                let sampleCount = getSampleCount(for: sensor)
                bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensor.sdkType)
                print("🔧 초기 설정: \(sensor.rawValue) - \(sampleCount)개 샘플마다 배치 수신")
                
                // 각 센서별 예상 시간 출력
                switch sensor.sdkType {
                case .eeg:
                    let expectedTime = Double(sampleCount) / 250.0 // EEG는 250Hz
                    print("   → EEG: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .ppg:
                    let expectedTime = Double(sampleCount) / 50.0 // PPG는 50Hz
                    print("   → PPG: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .accelerometer:
                    let expectedTime = Double(sampleCount) / 30.0 // ACC는 30Hz
                    print("   → ACC: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .battery:
                    break // 배터리는 예상 시간 출력 안함
                }
            } else {
                let duration = getDuration(for: sensor)
                bluetoothKit.setDataCollection(timeInterval: TimeInterval(duration), for: sensor.sdkType)
                print("🔧 초기 설정: \(sensor.rawValue) - \(duration)초마다 배치 수신")
                
                // 각 센서별 예상 샘플 수 출력
                switch sensor.sdkType {
                case .eeg:
                    let expectedSamples = duration * 250 // EEG는 250Hz
                    print("   → EEG: \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
                case .ppg:
                    let expectedSamples = duration * 50 // PPG는 50Hz
                    print("   → PPG: \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
                case .accelerometer:
                    let expectedSamples = duration * 30 // ACC는 30Hz
                    print("   → ACC: \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
                case .battery:
                    break // 배터리는 예상 샘플 수 출력 안함
                }
            }
        }
        
        isConfigured = true
    }
    
    private func applyConfigurationChanges() {
        // 선택된 센서를 로거에 업데이트
        let selectedSensorTypes = Set(selectedSensors.map { $0.sdkType })
        batchDelegate?.updateSelectedSensors(selectedSensorTypes)
        
        for sensor in selectedSensors {
            if selectedCollectionMode == .sampleCount {
                let sampleCount = getSampleCount(for: sensor)
                bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensor.sdkType)
                print("🔄 자동 변경: \(sensor.rawValue) - \(sampleCount)개 샘플마다 배치 수신")
                
                // 각 센서별 예상 시간 출력
                switch sensor.sdkType {
                case .eeg:
                    let expectedTime = Double(sampleCount) / 250.0 // EEG는 250Hz
                    print("   → EEG: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .ppg:
                    let expectedTime = Double(sampleCount) / 50.0 // PPG는 50Hz
                    print("   → PPG: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .accelerometer:
                    let expectedTime = Double(sampleCount) / 30.0 // ACC는 30Hz
                    print("   → ACC: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .battery:
                    break // 배터리는 예상 시간 출력 안함
                }
            } else {
                let duration = getDuration(for: sensor)
                bluetoothKit.setDataCollection(timeInterval: TimeInterval(duration), for: sensor.sdkType)
                print("🔄 자동 변경: \(sensor.rawValue) - \(duration)초마다 배치 수신")
                
                // 각 센서별 예상 샘플 수 출력
                switch sensor.sdkType {
                case .eeg:
                    let expectedSamples = duration * 250 // EEG는 250Hz
                    print("   → EEG: \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
                case .ppg:
                    let expectedSamples = duration * 50 // PPG는 50Hz
                    print("   → PPG: \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
                case .accelerometer:
                    let expectedSamples = duration * 30 // ACC는 30Hz
                    print("   → ACC: \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
                case .battery:
                    break // 배터리는 예상 샘플 수 출력 안함
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSampleCount(for sensor: SensorTypeOption) -> Int {
        switch sensor {
        case .eeg: return eegSampleCount
        case .ppg: return ppgSampleCount
        case .accelerometer: return accelerometerSampleCount
        }
    }
    
    private func getDuration(for sensor: SensorTypeOption) -> Int {
        switch sensor {
        case .eeg: return eegDurationSeconds
        case .ppg: return ppgDurationSeconds
        case .accelerometer: return accelerometerDurationSeconds
        }
    }
    
    private func removeConfiguration() {
        bluetoothKit.disableAllDataCollection()
        
        // 로거의 선택된 센서를 빈 세트로 업데이트하여 콘솔 출력 중지
        batchDelegate?.updateSelectedSensors(Set<SensorType>())
        
        // batchDelegate를 nil로 설정하여 콘솔 출력 중지
        bluetoothKit.batchDataDelegate = nil
        batchDelegate = nil
        isConfigured = false
        print("❌ 배치 데이터 수집 설정 해제")
    }
    
    // MARK: - Validation Methods
    
    private func validateAndUpdateSampleCount(_ text: String, for sensor: SensorTypeOption) {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                showValidationError = true
                validationMessage = "유효한 숫자를 입력해주세요"
            }
            return
        }
        
        let clampedValue = max(1, min(value, 100000))
        switch sensor {
        case .eeg: eegSampleCount = clampedValue
        case .ppg: ppgSampleCount = clampedValue
        case .accelerometer: accelerometerSampleCount = clampedValue
        }
        
        if clampedValue != value {
            DispatchQueue.main.async {
                switch sensor {
                case .eeg: eegSampleCountText = "\(clampedValue)"
                case .ppg: ppgSampleCountText = "\(clampedValue)"
                case .accelerometer: accelerometerSampleCountText = "\(clampedValue)"
                }
            }
        }
        
        showValidationError = false
        
        // 설정이 이미 완료된 상태에서만 자동 적용
        if isConfigured {
            applyConfigurationChanges()
        }
    }
    
    private func validateAndUpdateDuration(_ text: String, for sensor: SensorTypeOption) {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                showValidationError = true
                validationMessage = "유효한 숫자를 입력해주세요"
            }
            return
        }
        
        let clampedValue = max(1, min(value, 3600))
        switch sensor {
        case .eeg: eegDurationSeconds = clampedValue
        case .ppg: ppgDurationSeconds = clampedValue
        case .accelerometer: accelerometerDurationSeconds = clampedValue
        }
        
        if clampedValue != value {
            DispatchQueue.main.async {
                switch sensor {
                case .eeg: eegDurationText = "\(clampedValue)"
                case .ppg: ppgDurationText = "\(clampedValue)"
                case .accelerometer: accelerometerDurationText = "\(clampedValue)"
                }
            }
        }
        
        showValidationError = false
        
        // 설정이 이미 완료된 상태에서만 자동 적용
        if isConfigured {
            applyConfigurationChanges()
        }
    }
}

// MARK: - Console Logger for Batch Data

class BatchDataConsoleLogger: SensorBatchDataDelegate {
    private var batchCount: [String: Int] = [:]
    private let startTime = Date()
    private var selectedSensors: Set<SensorType> = []
    
    // 선택된 센서를 업데이트하는 메서드
    func updateSelectedSensors(_ sensors: Set<SensorType>) {
        selectedSensors = sensors
        print("📝 콘솔 출력 설정 업데이트: \(sensors.map { sensorTypeToString($0) }.joined(separator: ", "))")
    }
    
    private func sensorTypeToString(_ sensorType: SensorType) -> String {
        switch sensorType {
        case .eeg: return "EEG"
        case .ppg: return "PPG"
        case .accelerometer: return "ACC"
        case .battery: return "배터리"
        }
    }
    
    func didReceiveEEGBatch(_ readings: [EEGReading]) {
        // EEG가 선택된 센서에 포함되어 있을 때만 출력
        guard selectedSensors.contains(.eeg) else { return }
        
        let count = (batchCount["EEG"] ?? 0) + 1
        batchCount["EEG"] = count
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("🧠 EEG 배치 #\(count) 수신 - \(readings.count)개 샘플 (경과: \(String(format: "%.1f", elapsed))초)")
        
        // 모든 EEG 샘플 출력
        for (index, reading) in readings.enumerated() {
            print("   📊 샘플 #\(index + 1): CH1=\(String(format: "%.1f", reading.channel1))µV, CH2=\(String(format: "%.1f", reading.channel2))µV")
        }
        print("") // 배치 간 구분을 위한 빈 줄
    }
    
    func didReceivePPGBatch(_ readings: [PPGReading]) {
        // PPG가 선택된 센서에 포함되어 있을 때만 출력
        guard selectedSensors.contains(.ppg) else { return }
        
        let count = (batchCount["PPG"] ?? 0) + 1
        batchCount["PPG"] = count
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("❤️ PPG 배치 #\(count) 수신 - \(readings.count)개 샘플 (경과: \(String(format: "%.1f", elapsed))초)")
        
        // 모든 PPG 샘플 출력
        for (index, reading) in readings.enumerated() {
            print("   📊 샘플 #\(index + 1): RED=\(reading.red), IR=\(reading.ir)")
        }
        print("") // 배치 간 구분을 위한 빈 줄
    }
    
    func didReceiveAccelerometerBatch(_ readings: [AccelerometerReading]) {
        // 가속도계가 선택된 센서에 포함되어 있을 때만 출력
        guard selectedSensors.contains(.accelerometer) else { return }
        
        let count = (batchCount["ACCEL"] ?? 0) + 1
        batchCount["ACCEL"] = count
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("🏃 ACC 배치 #\(count) 수신 - \(readings.count)개 샘플 (경과: \(String(format: "%.1f", elapsed))초)")
        
        // 모든 ACC 샘플 출력
        for (index, reading) in readings.enumerated() {
            print("   📊 샘플 #\(index + 1): X=\(reading.x), Y=\(reading.y), Z=\(reading.z)")
        }
        print("") // 배치 간 구분을 위한 빈 줄
    }
    
    func didReceiveBatteryUpdate(_ reading: BatteryReading) {
        // 배터리가 선택된 센서에 포함되어 있을 때만 출력 (배터리는 보통 항상 포함되지만 확인)
        guard selectedSensors.contains(.battery) else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("🔋 배터리 업데이트 - \(reading.level)% (경과: \(String(format: "%.1f", elapsed))초)")
        print("") // 다른 로그와 구분을 위한 빈 줄
    }
}

#Preview {
    BatchDataCollectionView(bluetoothKit: BluetoothKit())
        .padding()
} 