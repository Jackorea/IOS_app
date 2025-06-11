import SwiftUI
import BluetoothKit

/// 배치 데이터 수집 설정을 관리하는 ViewModel
@MainActor
class BatchDataConfigurationViewModel: ObservableObject {
    
    // MARK: - Types
    
    enum CollectionMode: String, CaseIterable {
        case sampleCount = "샘플 수"
        case duration = "시간 (초)"
    }
    
    // MARK: - Configuration Data
    
    private struct SensorConfiguration {
        var sampleCount: Int
        var duration: Int
        var sampleCountText: String
        var durationText: String
        
        init(sampleCount: Int, duration: Int) {
            self.sampleCount = sampleCount
            self.duration = duration
            self.sampleCountText = "\(sampleCount)"
            self.durationText = "\(duration)"
        }
    }
    
    // MARK: - Published Properties
    
    @Published var selectedCollectionMode: CollectionMode = .sampleCount
    @Published var selectedSensors: Set<SensorType> = [.eeg, .ppg, .accelerometer]
    @Published var isConfigured = false
    @Published var showValidationError: Bool = false
    @Published var validationMessage: String = ""
    
    // 센서별 설정을 Dictionary로 관리하여 코드 중복 제거
    @Published private var sensorConfigurations: [SensorType: SensorConfiguration] = [
        .eeg: SensorConfiguration(sampleCount: 250, duration: 1),
        .ppg: SensorConfiguration(sampleCount: 50, duration: 1),
        .accelerometer: SensorConfiguration(sampleCount: 30, duration: 1)
    ]
    
    // MARK: - Computed Properties for UI Binding
    
    var eegSampleCount: Int {
        get { sensorConfigurations[.eeg]?.sampleCount ?? 250 }
        set { 
            sensorConfigurations[.eeg]?.sampleCount = newValue
            if isConfigured { applyChanges() }
        }
    }
    
    var ppgSampleCount: Int {
        get { sensorConfigurations[.ppg]?.sampleCount ?? 50 }
        set { 
            sensorConfigurations[.ppg]?.sampleCount = newValue
            if isConfigured { applyChanges() }
        }
    }
    
    var accelerometerSampleCount: Int {
        get { sensorConfigurations[.accelerometer]?.sampleCount ?? 30 }
        set { 
            sensorConfigurations[.accelerometer]?.sampleCount = newValue
            if isConfigured { applyChanges() }
        }
    }
    
    var eegDurationSeconds: Int {
        get { sensorConfigurations[.eeg]?.duration ?? 1 }
        set { 
            sensorConfigurations[.eeg]?.duration = newValue
            if isConfigured { applyChanges() }
        }
    }
    
    var ppgDurationSeconds: Int {
        get { sensorConfigurations[.ppg]?.duration ?? 1 }
        set { 
            sensorConfigurations[.ppg]?.duration = newValue
            if isConfigured { applyChanges() }
        }
    }
    
    var accelerometerDurationSeconds: Int {
        get { sensorConfigurations[.accelerometer]?.duration ?? 1 }
        set { 
            sensorConfigurations[.accelerometer]?.duration = newValue
            if isConfigured { applyChanges() }
        }
    }
    
    // Text field bindings
    var eegSampleCountText: String {
        get { sensorConfigurations[.eeg]?.sampleCountText ?? "250" }
        set { sensorConfigurations[.eeg]?.sampleCountText = newValue }
    }
    
    var ppgSampleCountText: String {
        get { sensorConfigurations[.ppg]?.sampleCountText ?? "50" }
        set { sensorConfigurations[.ppg]?.sampleCountText = newValue }
    }
    
    var accelerometerSampleCountText: String {
        get { sensorConfigurations[.accelerometer]?.sampleCountText ?? "30" }
        set { sensorConfigurations[.accelerometer]?.sampleCountText = newValue }
    }
    
    var eegDurationText: String {
        get { sensorConfigurations[.eeg]?.durationText ?? "1" }
        set { sensorConfigurations[.eeg]?.durationText = newValue }
    }
    
    var ppgDurationText: String {
        get { sensorConfigurations[.ppg]?.durationText ?? "1" }
        set { sensorConfigurations[.ppg]?.durationText = newValue }
    }
    
    var accelerometerDurationText: String {
        get { sensorConfigurations[.accelerometer]?.durationText ?? "1" }
        set { sensorConfigurations[.accelerometer]?.durationText = newValue }
    }
    
    // SDK 참조
    private let bluetoothKit: BluetoothKit
    private var batchDelegate: BatchDataConsoleLogger?
    
    // MARK: - Initialization
    
    init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
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
    
    func updateSensorSelection(_ sensors: Set<SensorType>) {
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
    
    func validateSampleCount(_ text: String, for sensor: SensorType) -> Bool {
        return validateAndUpdateValue(text, for: sensor, type: .sampleCount, range: 1...100000)
    }
    
    func validateDuration(_ text: String, for sensor: SensorType) -> Bool {
        return validateAndUpdateValue(text, for: sensor, type: .duration, range: 1...3600)
    }
    
    // MARK: - Helper Methods
    
    func getSampleCount(for sensor: SensorType) -> Int {
        return sensorConfigurations[sensor]?.sampleCount ?? 0
    }
    
    func getDuration(for sensor: SensorType) -> Int {
        return sensorConfigurations[sensor]?.duration ?? 0
    }
    
    func getExpectedTime(for sensor: SensorType, sampleCount: Int) -> Double {
        return sensor.expectedTime(for: sampleCount)
    }
    
    func getExpectedSamples(for sensor: SensorType, duration: Int) -> Int {
        return sensor.expectedSamples(for: TimeInterval(duration))
    }
    
    // MARK: - Private Methods
    
    private enum ValueType {
        case sampleCount
        case duration
    }
    
    private func validateAndUpdateValue(_ text: String, for sensor: SensorType, type: ValueType, range: ClosedRange<Int>) -> Bool {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                showValidationError = true
                validationMessage = "유효한 숫자를 입력해주세요"
            }
            return false
        }
        
        let clampedValue = max(range.lowerBound, min(value, range.upperBound))
        
        switch type {
        case .sampleCount:
            updateSampleCount(clampedValue, for: sensor, originalValue: value)
        case .duration:
            updateDuration(clampedValue, for: sensor, originalValue: value)
        }
        
        showValidationError = false
        return true
    }
    
    private func setupBatchDelegate() {
        if batchDelegate == nil {
            batchDelegate = BatchDataConsoleLogger()
            bluetoothKit.batchDataDelegate = batchDelegate
        }
        
        batchDelegate?.updateSelectedSensors(selectedSensors)
    }
    
    private func configureAllSensors() {
        let allSensorTypes: [SensorType] = [.eeg, .ppg, .accelerometer]
        
        for sensorType in allSensorTypes {
            if selectedSensors.contains(sensorType) {
                configureSensor(sensorType, isInitial: true)
            } else {
                bluetoothKit.disableDataCollection(for: sensorType)
                print("🚫 초기 비활성화: \(sensorType.displayName) - 데이터 수집 제외")
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
    
    private func configureSensor(_ sensor: SensorType, isInitial: Bool = false) {
        let prefix = isInitial ? "🔧 초기 설정" : "🔄 자동 변경"
        
        if selectedCollectionMode == .sampleCount {
            let sampleCount = getSampleCount(for: sensor)
            bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensor)
            
            let expectedTime = getExpectedTime(for: sensor, sampleCount: sampleCount)
            print("\(prefix): \(sensor.displayName) - \(sampleCount)개 샘플마다 배치 수신")
            print("   → \(sensor.displayName): \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
        } else {
            let duration = getDuration(for: sensor)
            bluetoothKit.setDataCollection(timeInterval: TimeInterval(duration), for: sensor)
            
            let expectedSamples = getExpectedSamples(for: sensor, duration: duration)
            print("\(prefix): \(sensor.displayName) - \(duration)초마다 배치 수신")
            print("   → \(sensor.displayName): \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
        }
    }
    
    private func updateSampleCount(_ value: Int, for sensor: SensorType, originalValue: Int) {
        sensorConfigurations[sensor]?.sampleCount = value
        if value != originalValue {
            sensorConfigurations[sensor]?.sampleCountText = "\(value)"
        }
    }
    
    private func updateDuration(_ value: Int, for sensor: SensorType, originalValue: Int) {
        sensorConfigurations[sensor]?.duration = value
        if value != originalValue {
            sensorConfigurations[sensor]?.durationText = "\(value)"
        }
    }
} 