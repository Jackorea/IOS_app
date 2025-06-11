import SwiftUI
import BluetoothKit

/// 배치 데이터 수집 설정을 관리하는 ViewModel
@MainActor
class BatchDataConfigurationViewModel: ObservableObject {
    
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
        
        var sampleRate: Double {
            return sdkType.sampleRate
        }
    }
    
    // MARK: - Published Properties
    @Published var selectedCollectionMode: CollectionMode = .sampleCount
    @Published var selectedSensors: Set<SensorTypeOption> = [.eeg, .ppg, .accelerometer]
    @Published var isConfigured = false
    
    // 센서별 샘플 수 설정
    @Published var eegSampleCount: Int = 250 {
        didSet { if isConfigured { applyChanges() } }
    }
    @Published var ppgSampleCount: Int = 50 {
        didSet { if isConfigured { applyChanges() } }
    }
    @Published var accelerometerSampleCount: Int = 30 {
        didSet { if isConfigured { applyChanges() } }
    }
    
    // 센서별 시간 설정
    @Published var eegDurationSeconds: Int = 1 {
        didSet { if isConfigured { applyChanges() } }
    }
    @Published var ppgDurationSeconds: Int = 1 {
        didSet { if isConfigured { applyChanges() } }
    }
    @Published var accelerometerDurationSeconds: Int = 1 {
        didSet { if isConfigured { applyChanges() } }
    }
    
    // 텍스트 필드 상태
    @Published var eegSampleCountText: String = "250"
    @Published var ppgSampleCountText: String = "50"
    @Published var accelerometerSampleCountText: String = "30"
    @Published var eegDurationText: String = "1"
    @Published var ppgDurationText: String = "1"
    @Published var accelerometerDurationText: String = "1"
    
    // 유효성 검사
    @Published var showValidationError: Bool = false
    @Published var validationMessage: String = ""
    
    // SDK 참조
    private let bluetoothKit: BluetoothKit
    private var batchDelegate: BatchDataConsoleLogger?
    
    init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
        setupTextFieldBindings()
    }
    
    // MARK: - Public Methods
    
    func applyInitialConfiguration() {
        guard !selectedSensors.isEmpty else { return }
        
        setupBatchDelegate()
        configureAllSensors()
        isConfigured = true
    }
    
    func removeConfiguration() {
        bluetoothKit.disableAllDataCollection()
        batchDelegate?.updateSelectedSensors(Set<SensorType>())
        bluetoothKit.batchDataDelegate = nil
        batchDelegate = nil
        isConfigured = false
        print("❌ 배치 데이터 수집 설정 해제")
    }
    
    func updateSensorSelection(_ sensors: Set<SensorTypeOption>) {
        selectedSensors = sensors
        if isConfigured {
            applyChanges()
        }
    }
    
    func updateCollectionMode(_ mode: CollectionMode) {
        selectedCollectionMode = mode
        if isConfigured {
            applyChanges()
        }
    }
    
    // MARK: - Validation Methods
    
    func validateSampleCount(_ text: String, for sensor: SensorTypeOption) -> Bool {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                showValidationError = true
                validationMessage = "유효한 숫자를 입력해주세요"
            }
            return false
        }
        
        let clampedValue = max(1, min(value, 100000))
        updateSampleCount(clampedValue, for: sensor, originalValue: value)
        showValidationError = false
        return true
    }
    
    func validateDuration(_ text: String, for sensor: SensorTypeOption) -> Bool {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                showValidationError = true
                validationMessage = "유효한 숫자를 입력해주세요"
            }
            return false
        }
        
        let clampedValue = max(1, min(value, 3600))
        updateDuration(clampedValue, for: sensor, originalValue: value)
        showValidationError = false
        return true
    }
    
    // MARK: - Helper Methods
    
    func getSampleCount(for sensor: SensorTypeOption) -> Int {
        switch sensor {
        case .eeg: return eegSampleCount
        case .ppg: return ppgSampleCount
        case .accelerometer: return accelerometerSampleCount
        }
    }
    
    func getDuration(for sensor: SensorTypeOption) -> Int {
        switch sensor {
        case .eeg: return eegDurationSeconds
        case .ppg: return ppgDurationSeconds
        case .accelerometer: return accelerometerDurationSeconds
        }
    }
    
    func getExpectedTime(for sensor: SensorTypeOption, sampleCount: Int) -> Double {
        return Double(sampleCount) / sensor.sampleRate
    }
    
    func getExpectedSamples(for sensor: SensorTypeOption, duration: Int) -> Int {
        return Int(Double(duration) * sensor.sampleRate)
    }
    
    // MARK: - Private Methods
    
    private func setupTextFieldBindings() {
        eegSampleCountText = "\(eegSampleCount)"
        ppgSampleCountText = "\(ppgSampleCount)"
        accelerometerSampleCountText = "\(accelerometerSampleCount)"
        eegDurationText = "\(eegDurationSeconds)"
        ppgDurationText = "\(ppgDurationSeconds)"
        accelerometerDurationText = "\(accelerometerDurationSeconds)"
    }
    
    private func setupBatchDelegate() {
        if batchDelegate == nil {
            batchDelegate = BatchDataConsoleLogger()
            bluetoothKit.batchDataDelegate = batchDelegate
        }
        
        let selectedSensorTypes = Set(selectedSensors.map { $0.sdkType })
        batchDelegate?.updateSelectedSensors(selectedSensorTypes)
    }
    
    private func configureAllSensors() {
        let allSensorTypes: [SensorTypeOption] = [.eeg, .ppg, .accelerometer]
        
        for sensorOption in allSensorTypes {
            if selectedSensors.contains(sensorOption) {
                configureSensor(sensorOption, isInitial: true)
            } else {
                bluetoothKit.disableDataCollection(for: sensorOption.sdkType)
                print("🚫 초기 비활성화: \(sensorOption.rawValue) - 데이터 수집 제외")
            }
        }
    }
    
    private func applyChanges() {
        setupBatchDelegate()
        
        if bluetoothKit.isRecording {
            bluetoothKit.updateRecordingSensors()
        }
        
        configureAllSensors()
    }
    
    private func configureSensor(_ sensor: SensorTypeOption, isInitial: Bool = false) {
        let prefix = isInitial ? "🔧 초기 설정" : "🔄 자동 변경"
        
        if selectedCollectionMode == .sampleCount {
            let sampleCount = getSampleCount(for: sensor)
            bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensor.sdkType)
            
            let expectedTime = getExpectedTime(for: sensor, sampleCount: sampleCount)
            print("\(prefix): \(sensor.rawValue) - \(sampleCount)개 샘플마다 배치 수신")
            print("   → \(sensor.rawValue): \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
        } else {
            let duration = getDuration(for: sensor)
            bluetoothKit.setDataCollection(timeInterval: TimeInterval(duration), for: sensor.sdkType)
            
            let expectedSamples = getExpectedSamples(for: sensor, duration: duration)
            print("\(prefix): \(sensor.rawValue) - \(duration)초마다 배치 수신")
            print("   → \(sensor.rawValue): \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
        }
    }
    
    private func updateSampleCount(_ value: Int, for sensor: SensorTypeOption, originalValue: Int) {
        switch sensor {
        case .eeg: 
            eegSampleCount = value
            if value != originalValue {
                eegSampleCountText = "\(value)"
            }
        case .ppg: 
            ppgSampleCount = value
            if value != originalValue {
                ppgSampleCountText = "\(value)"
            }
        case .accelerometer: 
            accelerometerSampleCount = value
            if value != originalValue {
                accelerometerSampleCountText = "\(value)"
            }
        }
    }
    
    private func updateDuration(_ value: Int, for sensor: SensorTypeOption, originalValue: Int) {
        switch sensor {
        case .eeg: 
            eegDurationSeconds = value
            if value != originalValue {
                eegDurationText = "\(value)"
            }
        case .ppg: 
            ppgDurationSeconds = value
            if value != originalValue {
                ppgDurationText = "\(value)"
            }
        case .accelerometer: 
            accelerometerDurationSeconds = value
            if value != originalValue {
                accelerometerDurationText = "\(value)"
            }
        }
    }
} 