import SwiftUI
import BluetoothKit
import Combine

/// BatchDataConfigurationManager를 SwiftUI에서 사용할 수 있도록 래핑하는 ViewModel
/// SDK의 순수 비즈니스 로직과 UI를 연결하는 어댑터 역할을 합니다.
@MainActor
class BatchDataConfigurationViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI 바인딩용)
    
    @Published public var selectedCollectionMode: BatchDataConfigurationManager.CollectionMode = .sampleCount
    @Published public var selectedSensors: Set<SensorType> = [.eeg, .ppg, .accelerometer]
    @Published public var isMonitoringActive = false
    @Published public var showRecordingChangeWarning = false
    @Published public var pendingSensorSelection: Set<SensorType>?
    @Published public var pendingConfigurationChange: BatchDataConfigurationManager.PendingConfigurationChange?
    @Published public var sensorConfigurations: [SensorType: BatchDataConfigurationManager.SensorConfiguration] = [:]
    
    // UI 전용 상태
    @Published public var showValidationError: Bool = false
    @Published public var validationMessage: String = ""
    
    // MARK: - SDK Instance
    
    /// 통합된 BluetoothKit 인스턴스 (단일 진입점)
    private let bluetoothKit: BluetoothKit
    
    // MARK: - Initialization
    
    /// 새로운 BatchDataConfigurationViewModel 인스턴스를 생성합니다.
    public init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
        
        // 초기 상태 동기화
        syncInitialState()
    }
    
    // MARK: - Public Interface (통합된 BluetoothKit API 사용)
    
    /// 모니터링을 시작합니다.
    public func startMonitoring() {
        bluetoothKit.startBatchMonitoring()
        // 즉시 상태 업데이트 (UI 반응성 향상)
        isMonitoringActive = true
    }
    
    /// 모니터링을 중지합니다.
    public func stopMonitoring() {
        bluetoothKit.stopBatchMonitoring()
        // 즉시 상태 업데이트 (UI 반응성 향상)
        isMonitoringActive = false
    }
    
    /// 센서 선택을 업데이트합니다.
    public func updateSensorSelection(_ sensors: Set<SensorType>) {
        bluetoothKit.updateBatchSensorSelection(sensors)
        // UI 동기화를 위해 로컬 상태도 업데이트
        selectedSensors = sensors
    }
    
    /// 수집 모드를 업데이트합니다.
    public func updateCollectionMode(_ mode: BatchDataConfigurationManager.CollectionMode) {
        bluetoothKit.updateBatchCollectionMode(mode)
    }
    
    /// 사용자가 경고 팝업에서 "기록 중지 후 변경"을 선택했을 때 호출
    public func confirmSensorChangeWithRecordingStop() {
        bluetoothKit.confirmBatchSensorChangeWithRecordingStop()
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출
    public func cancelSensorChange() {
        bluetoothKit.cancelBatchSensorChange()
    }
    
    // MARK: - Sensor Configuration Access
    
    public func getSampleCount(for sensor: SensorType) -> Int {
        return bluetoothKit.getBatchSampleCount(for: sensor)
    }
    
    public func getSeconds(for sensor: SensorType) -> Int {
        return bluetoothKit.getBatchSeconds(for: sensor)
    }
    
    public func getSampleCountText(for sensor: SensorType) -> String {
        return bluetoothKit.getBatchSampleCountText(for: sensor)
    }
    
    public func getSecondsText(for sensor: SensorType) -> String {
        return bluetoothKit.getBatchSecondsText(for: sensor)
    }
    
    public func getMinutes(for sensor: SensorType) -> Int {
        return bluetoothKit.getBatchMinutes(for: sensor)
    }
    
    public func getMinutesText(for sensor: SensorType) -> String {
        return bluetoothKit.getBatchMinutesText(for: sensor)
    }
    
    public func setSampleCount(_ value: Int, for sensor: SensorType) {
        bluetoothKit.setBatchSampleCount(value, for: sensor)
    }
    
    public func setSeconds(_ value: Int, for sensor: SensorType) {
        bluetoothKit.setBatchSeconds(value, for: sensor)
    }
    
    public func setMinutes(_ value: Int, for sensor: SensorType) {
        bluetoothKit.setBatchMinutes(value, for: sensor)
    }
    
    public func setSampleCountText(_ text: String, for sensor: SensorType) {
        bluetoothKit.setBatchSampleCountText(text, for: sensor)
    }
    
    public func setSecondsText(_ text: String, for sensor: SensorType) {
        bluetoothKit.setBatchSecondsText(text, for: sensor)
    }
    
    public func setMinutesText(_ text: String, for sensor: SensorType) {
        bluetoothKit.setBatchMinutesText(text, for: sensor)
    }
    
    // MARK: - Validation Methods
    
    public func validateSampleCount(_ text: String, for sensor: SensorType) -> Bool {
        let result = bluetoothKit.validateBatchSampleCount(text, for: sensor)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    public func validateSeconds(_ text: String, for sensor: SensorType) -> Bool {
        let result = bluetoothKit.validateBatchSeconds(text, for: sensor)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    public func validateMinutes(_ text: String, for sensor: SensorType) -> Bool {
        let result = bluetoothKit.validateBatchMinutes(text, for: sensor)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    // MARK: - Helper Methods
    
    public func getExpectedTime(for sensor: SensorType, sampleCount: Int) -> Double {
        return bluetoothKit.getBatchExpectedTime(for: sensor, sampleCount: sampleCount)
    }
    
    public func getExpectedSamples(for sensor: SensorType, seconds: Int) -> Int {
        return bluetoothKit.getBatchExpectedSamples(for: sensor, seconds: seconds)
    }
    
    public func getExpectedSamplesForMinutes(for sensor: SensorType, minutes: Int) -> Int {
        return bluetoothKit.getBatchExpectedSamplesForMinutes(for: sensor, minutes: minutes)
    }
    
    public func getExpectedMinutes(for sensor: SensorType, sampleCount: Int) -> Double {
        return bluetoothKit.getBatchExpectedMinutes(for: sensor, sampleCount: sampleCount)
    }
    
    public func resetToDefaults() {
        bluetoothKit.resetBatchToDefaults()
    }
    
    public func getConfigurationSummary() -> String {
        return bluetoothKit.getBatchConfigurationSummary()
    }
    
    public func isSensorSelected(_ sensor: SensorType) -> Bool {
        return bluetoothKit.isBatchSensorSelected(sensor)
    }
    
    /// 가속도계 모드를 업데이트합니다.
    /// 실시간 모니터링 중에 모드 변경을 콘솔에 즉시 반영합니다.
    public func updateAccelerometerMode(_ mode: AccelerometerMode) {
        bluetoothKit.updateBatchAccelerometerMode(mode)
    }
    
    // MARK: - Private Methods
    
    /// BluetoothKit의 초기 상태를 ViewModel에 동기화합니다.
    private func syncInitialState() {
        selectedCollectionMode = bluetoothKit.batchSelectedCollectionMode
        selectedSensors = bluetoothKit.batchSelectedSensors
        isMonitoringActive = bluetoothKit.isBatchMonitoringActive
        showRecordingChangeWarning = bluetoothKit.showBatchRecordingChangeWarning
        pendingSensorSelection = bluetoothKit.batchPendingSensorSelection
        pendingConfigurationChange = bluetoothKit.batchPendingConfigurationChange
    }
}

// MARK: - Type Aliases for Backward Compatibility

extension BatchDataConfigurationViewModel {
    typealias CollectionMode = BatchDataConfigurationManager.CollectionMode
} 