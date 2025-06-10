import SwiftUI
import BluetoothKit

// MARK: - Batch Data Collection View

/// 데이터 수집 설정을 위한 뷰 - 샘플 수와 시간 기반 수집 지원
struct BatchDataCollectionView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    @State private var selectedCollectionMode: CollectionMode = .sampleCount
    @State private var sampleCount: Int = 1000
    @State private var durationSeconds: Int = 30
    @State private var selectedSensors: Set<SensorTypeOption> = [.eeg, .ppg, .accelerometer]
    @State private var isConfigured = false
    @State private var sampleCountText: String = "1000"
    @State private var durationText: String = "30"
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""
    @State private var batchDelegate: BatchDataConsoleLogger?
    @State private var stopBatchWithRecording: Bool = false
    
    enum CollectionMode: String, CaseIterable {
        case sampleCount = "샘플 수"
        case duration = "시간 (초)"
    }
    
    enum SensorTypeOption: String, CaseIterable {
        case eeg = "EEG"
        case ppg = "PPG"
        case accelerometer = "가속도계"
        case battery = "배터리"
        
        var sdkType: SensorType {
            switch self {
            case .eeg: return .eeg
            case .ppg: return .ppg
            case .accelerometer: return .accelerometer
            case .battery: return .battery
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
            
            // 배치 수집 예시 설명
            batchCollectionExplanation
            
            Divider()
            
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
            
            // 배치 수집 제어 옵션
            if isConfigured {
                batchControlOptions
            }
            
            // 설정 상태
            if isConfigured {
                configurationStatusView
            }
            
            // 수집 컨트롤 버튼
            collectionControlButtons
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            setupBatchDelegate()
        }
    }
    
    private var batchCollectionExplanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📊 배치 데이터 수집 방식")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• 시간 기반: 1초 → 1초마다 250개 EEG 샘플 수신")
                Text("• 시간 기반: 2초 → 2초마다 500개 EEG 샘플 수신")
                Text("• 샘플 기반: 1000개 → 4초 후 1000개 EEG 샘플 수신")
                Text("• 콘솔에서 배치 수신 시점과 샘플 개수 확인 가능")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var sampleCountConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("목표 샘플 수")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("예: 1000", text: $sampleCountText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
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
                
                HStack {
                    Text("• 최소: 1 샘플")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("• 최대: 100,000 샘플")
                        .font(.caption2)
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
                    TextField("예: 30", text: $durationText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
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
                
                HStack {
                    Text("• 최소: 1초")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("• 최대: 3,600초 (1시간)")
                        .font(.caption2)
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
    
    private var batchControlOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("배치 수집 제어 옵션")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Toggle("배치 수집 중지 시 데이터 수집 중지", isOn: $stopBatchWithRecording)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
    
    private var collectionControlButtons: some View {
        VStack(spacing: 12) {
            if isConfigured {
                HStack(spacing: 12) {
                    Button("설정 해제") {
                        removeConfiguration()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
                    
                    Button(bluetoothKit.isRecording ? "기록 중지" : "기록 시작") {
                        if bluetoothKit.isRecording {
                            stopDataCollection()
                        } else {
                            startDataCollection()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bluetoothKit.isRecording ? .red : .green)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Button("설정 적용") {
                    applyConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
                .disabled(selectedSensors.isEmpty || !bluetoothKit.isConnected)
            }
        }
    }
    
    private func startDataCollection() {
        print("🟢 기록 시작")
        
        // 배치 데이터 델리게이트 다시 설정 (혹시 없어졌을 경우 대비)
        if batchDelegate == nil {
            setupBatchDelegate()
        }
        
        bluetoothKit.startRecording()
        print("✅ 기록이 시작되었습니다 - 배치 데이터 수신 중...")
    }
    
    private func stopDataCollection() {
        print("🔴 기록 중지")
        
        // 1. 기록 중지
        bluetoothKit.stopRecording()
        
        // 2. 사용자 설정에 따라 배치 데이터 수집도 중지
        if stopBatchWithRecording {
            print("⏹️ 배치 데이터 수집도 함께 중지합니다")
            bluetoothKit.disableAllDataCollection()
            bluetoothKit.batchDataDelegate = nil
            batchDelegate = nil
            isConfigured = false
            print("❌ 모든 데이터 수집이 중지되었습니다")
        } else {
            print("⏹️ 기록이 중지되었습니다")
            print("💡 배치 데이터 수집은 계속 활성화 상태입니다")
            print("   → 콘솔에서 배치 데이터가 계속 수신됩니다")
            print("   → 완전히 중지하려면 '설정 해제' 버튼을 누르세요")
        }
    }
    
    private func applyConfiguration() {
        guard !selectedSensors.isEmpty && bluetoothKit.isConnected else { return }
        
        // 먼저 모든 데이터 수집 비활성화
        bluetoothKit.disableAllDataCollection()
        
        // 배치 데이터 델리게이트 설정 (콘솔 출력용)
        setupBatchDelegate()
        
        // 선택된 센서들에 대해 설정 적용
        for sensor in selectedSensors {
            if selectedCollectionMode == .sampleCount {
                bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensor.sdkType)
                print("🔧 설정 적용: \(sensor.rawValue) - \(sampleCount)개 샘플마다 배치 수신")
            } else {
                bluetoothKit.setDataCollection(timeInterval: TimeInterval(durationSeconds), for: sensor.sdkType)
                print("🔧 설정 적용: \(sensor.rawValue) - \(durationSeconds)초마다 배치 수신")
                
                // EEG의 경우 예상 샘플 수 출력
                if sensor.sdkType == .eeg {
                    let expectedSamples = durationSeconds * 250 // EEG는 250Hz
                    print("   → EEG: \(durationSeconds)초마다 약 \(expectedSamples)개 샘플 예상")
                }
            }
        }
        
        isConfigured = true
        print("✅ 배치 데이터 수집 설정 완료")
        print("💡 '기록 시작' 버튼을 눌러 데이터 수신을 시작하세요")
    }
    
    private func removeConfiguration() {
        print("🔴 배치 데이터 수집 완전 중지")
        
        // 기록도 중지
        if bluetoothKit.isRecording {
            bluetoothKit.stopRecording()
        }
        
        // 배치 데이터 수집 완전 해제
        bluetoothKit.disableAllDataCollection()
        bluetoothKit.batchDataDelegate = nil
        batchDelegate = nil
        isConfigured = false
        
        print("❌ 모든 데이터 수집이 중지되었습니다")
    }
    
    private func setupBatchDelegate() {
        batchDelegate = BatchDataConsoleLogger()
        bluetoothKit.batchDataDelegate = batchDelegate
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