import SwiftUI
import BluetoothKit

// MARK: - Batch Data Collection View

/// 데이터 수집 설정을 위한 뷰 - 샘플 수와 시간 기반 수집 지원
struct BatchDataCollectionView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    @State private var selectedCollectionMode: CollectionMode = .sampleCount
    @State private var sampleCount: Int = 500
    @State private var durationSeconds: Int = 3
    @State private var selectedSensors: Set<SensorTypeOption> = [.eeg, .ppg, .accelerometer]
    @State private var isConfigured = false
    @State private var sampleCountText: String = "500"
    @State private var durationText: String = "3"
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
        case accelerometer = "가속도계"
        
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
                        autoApplyConfiguration()
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
        .onAppear {
            setupBatchDelegate()
        }
    }
    
    private var sampleCountConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("목표 샘플 수")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("예: 500", text: $sampleCountText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: sampleCountText) { newValue in
                            validateAndUpdateSampleCount(newValue)
                        }
                        .onAppear {
                            sampleCountText = "\(sampleCount)"
                        }
                    
                    Text("샘플")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var durationConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("수집 시간")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
            HStack {
                    TextField("예: 3", text: $durationText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($isTextFieldFocused)
                        .onChange(of: durationText) { newValue in
                            validateAndUpdateDuration(newValue)
                        }
                        .onAppear {
                            durationText = "\(durationSeconds)"
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
                autoApplyConfiguration()
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
        VStack(spacing: 8) {
            HStack {
                Text("설정 완료")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if selectedCollectionMode == .sampleCount {
                    Text("샘플 수: \(sampleCount)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        } else {
                    Text("시간: \(durationSeconds)초")
                        .font(.subheadline)
                        .foregroundColor(.blue)
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
    
    private func setupBatchDelegate() {
        batchDelegate = BatchDataConsoleLogger()
        bluetoothKit.batchDataDelegate = batchDelegate
    }
    
    // MARK: - Configuration Methods
    
    private func applyInitialConfiguration() {
        guard !selectedSensors.isEmpty && bluetoothKit.isConnected else { return }
        
        // 먼저 모든 데이터 수집 비활성화
        bluetoothKit.disableAllDataCollection()
        
        // 배치 데이터 델리게이트 설정 (콘솔 출력용)
        setupBatchDelegate()
        
        // 선택된 센서들에 대해 설정 적용
        for sensor in selectedSensors {
            if selectedCollectionMode == .sampleCount {
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
                    let expectedTime = Double(sampleCount) / 30.0 // 가속도계는 30Hz
                    print("   → 가속도계: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .battery:
                    break // 배터리는 예상 시간 출력 안함
                }
            } else {
                bluetoothKit.setDataCollection(timeInterval: TimeInterval(durationSeconds), for: sensor.sdkType)
                print("🔧 초기 설정: \(sensor.rawValue) - \(durationSeconds)초마다 배치 수신")
                
                // 각 센서별 예상 샘플 수 출력
                switch sensor.sdkType {
                case .eeg:
                    let expectedSamples = durationSeconds * 250 // EEG는 250Hz
                    print("   → EEG: \(durationSeconds)초마다 약 \(expectedSamples)개 샘플 예상")
                case .ppg:
                    let expectedSamples = durationSeconds * 50 // PPG는 50Hz
                    print("   → PPG: \(durationSeconds)초마다 약 \(expectedSamples)개 샘플 예상")
                case .accelerometer:
                    let expectedSamples = durationSeconds * 30 // 가속도계는 30Hz
                    print("   → 가속도계: \(durationSeconds)초마다 약 \(expectedSamples)개 샘플 예상")
                case .battery:
                    break // 배터리는 예상 샘플 수 출력 안함
                }
            }
        }
        
        isConfigured = true
        print("✅ 배치 데이터 수집 시작 - 이제 센서 변경 시 자동 적용됩니다")
    }
    
    private func autoApplyConfiguration() {
        // 설정이 완료된 상태에서만 자동 적용
        guard isConfigured else { return }
        
        // 연결되지 않았거나 센서가 선택되지 않은 경우 설정 해제
        guard bluetoothKit.isConnected && !selectedSensors.isEmpty else {
            removeConfiguration()
            return
        }
        
        // 기존 설정 제거 후 새로 적용
        bluetoothKit.disableAllDataCollection()
        
        // 배치 데이터 델리게이트 설정 (콘솔 출력용)
        setupBatchDelegate()
        
        // 선택된 센서들에 대해 설정 적용
        for sensor in selectedSensors {
            if selectedCollectionMode == .sampleCount {
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
                    let expectedTime = Double(sampleCount) / 30.0 // 가속도계는 30Hz
                    print("   → 가속도계: \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
                case .battery:
                    break // 배터리는 예상 시간 출력 안함
                }
            } else {
                bluetoothKit.setDataCollection(timeInterval: TimeInterval(durationSeconds), for: sensor.sdkType)
                print("🔄 자동 변경: \(sensor.rawValue) - \(durationSeconds)초마다 배치 수신")
                
                // 각 센서별 예상 샘플 수 출력
                switch sensor.sdkType {
                case .eeg:
                    let expectedSamples = durationSeconds * 250 // EEG는 250Hz
                    print("   → EEG: \(durationSeconds)초마다 약 \(expectedSamples)개 샘플 예상")
                case .ppg:
                    let expectedSamples = durationSeconds * 50 // PPG는 50Hz
                    print("   → PPG: \(durationSeconds)초마다 약 \(expectedSamples)개 샘플 예상")
                case .accelerometer:
                    let expectedSamples = durationSeconds * 30 // 가속도계는 30Hz
                    print("   → 가속도계: \(durationSeconds)초마다 약 \(expectedSamples)개 샘플 예상")
                case .battery:
                    break // 배터리는 예상 샘플 수 출력 안함
                }
            }
        }
        
        print("✅ 센서 설정 자동 변경 완료")
    }
    
    private func removeConfiguration() {
        bluetoothKit.disableAllDataCollection()
        // batchDelegate를 nil로 설정하여 콘솔 출력 중지
        bluetoothKit.batchDataDelegate = nil
        batchDelegate = nil
        isConfigured = false
        print("❌ 배치 데이터 수집 설정 해제")
    }
    
    // MARK: - Validation Methods
    
    private func validateAndUpdateSampleCount(_ text: String) {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                showValidationError = true
                validationMessage = "유효한 숫자를 입력해주세요"
            }
            return
        }
        
        let clampedValue = max(1, min(value, 100000))
        sampleCount = clampedValue
        
        if clampedValue != value {
            DispatchQueue.main.async {
                sampleCountText = "\(clampedValue)"
            }
        }
        
        showValidationError = false
        
        // 설정이 이미 완료된 상태에서만 자동 적용
        if isConfigured {
            autoApplyConfiguration()
        }
    }
    
    private func validateAndUpdateDuration(_ text: String) {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                showValidationError = true
                validationMessage = "유효한 숫자를 입력해주세요"
            }
            return
        }
        
        let clampedValue = max(1, min(value, 3600))
        durationSeconds = clampedValue
        
        if clampedValue != value {
            DispatchQueue.main.async {
                durationText = "\(clampedValue)"
            }
        }
        
        showValidationError = false
        
        // 설정이 이미 완료된 상태에서만 자동 적용
        if isConfigured {
            autoApplyConfiguration()
        }
    }
}

// MARK: - Console Logger for Batch Data

class BatchDataConsoleLogger: SensorBatchDataDelegate {
    private var batchCount: [String: Int] = [:]
    private let startTime = Date()
    
    func didReceiveEEGBatch(_ readings: [EEGReading]) {
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
        let count = (batchCount["PPG"] ?? 0) + 1
        batchCount["PPG"] = count
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("❤️ PPG 배치 #\(count) 수신 - \(readings.count)개 샘플 (경과: \(String(format: "%.1f", elapsed))초)")
        
        // 모든 PPG 샘플 출력
        for (index, reading) in readings.enumerated() {
            print("   📊 샘플 #\(index + 1): Red=\(reading.red), IR=\(reading.ir)")
        }
        print("") // 배치 간 구분을 위한 빈 줄
    }
    
    func didReceiveAccelerometerBatch(_ readings: [AccelerometerReading]) {
        let count = (batchCount["ACCEL"] ?? 0) + 1
        batchCount["ACCEL"] = count
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("🏃 가속도계 배치 #\(count) 수신 - \(readings.count)개 샘플 (경과: \(String(format: "%.1f", elapsed))초)")
        
        // 모든 가속도계 샘플 출력
        for (index, reading) in readings.enumerated() {
            print("   📊 샘플 #\(index + 1): X=\(reading.x), Y=\(reading.y), Z=\(reading.z)")
        }
        print("") // 배치 간 구분을 위한 빈 줄
    }
    
    func didReceiveBatteryUpdate(_ reading: BatteryReading) {
        let elapsed = Date().timeIntervalSince(startTime)
        print("🔋 배터리 업데이트 - \(reading.level)% (경과: \(String(format: "%.1f", elapsed))초)")
        print("") // 다른 로그와 구분을 위한 빈 줄
    }
}

#Preview {
    BatchDataCollectionView(bluetoothKit: BluetoothKit())
        .padding()
} 