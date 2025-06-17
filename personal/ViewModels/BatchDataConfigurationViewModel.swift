import SwiftUI
import BluetoothKit
import Combine

/// BatchDataConfigurationManager를 SwiftUI에서 사용할 수 있도록 래핑하는 ViewModel
/// SDK의 순수 비즈니스 로직과 UI를 연결하는 어댑터 역할을 합니다.
@MainActor
class BatchDataConfigurationViewModel: ObservableObject, BatchDataConfigurationManagerDelegate {
    
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
    
    /// 실제 비즈니스 로직을 담당하는 BatchDataConfigurationManager 인스턴스
    private let configurationManager: BatchDataConfigurationManager
    
    // MARK: - Initialization
    
    /// 새로운 BatchDataConfigurationViewModel 인스턴스를 생성합니다.
    public init(bluetoothKit: BluetoothKit) {
        self.configurationManager = BatchDataConfigurationManager(bluetoothKit: bluetoothKit)
        
        // 델리게이트 설정
        configurationManager.delegate = self
        
        // 초기 상태 동기화
        syncInitialState()
    }
    
    // MARK: - Public Interface (SDK 메서드들을 래핑)
    
    /// 모니터링을 시작합니다.
    public func startMonitoring() {
        configurationManager.startMonitoring()
    }
    
    /// 모니터링을 중지합니다.
    public func stopMonitoring() {
        configurationManager.stopMonitoring()
    }
    
    /// 센서 선택을 업데이트합니다.
    public func updateSensorSelection(_ sensors: Set<SensorType>) {
        configurationManager.updateSensorSelection(sensors)
    }
    
    /// 수집 모드를 업데이트합니다.
    public func updateCollectionMode(_ mode: BatchDataConfigurationManager.CollectionMode) {
        configurationManager.updateCollectionMode(mode)
    }
    
    /// 사용자가 경고 팝업에서 "기록 중지 후 변경"을 선택했을 때 호출
    public func confirmSensorChangeWithRecordingStop() {
        configurationManager.confirmSensorChangeWithRecordingStop()
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출
    public func cancelSensorChange() {
        configurationManager.cancelSensorChange()
    }
    
    // MARK: - Sensor Configuration Access
    
    public func getSampleCount(for sensor: SensorType) -> Int {
        return configurationManager.getSampleCount(for: sensor)
    }
    
    public func getDuration(for sensor: SensorType) -> Int {
        return configurationManager.getDuration(for: sensor)
    }
    
    public func getSampleCountText(for sensor: SensorType) -> String {
        return configurationManager.getSampleCountText(for: sensor)
    }
    
    public func getDurationText(for sensor: SensorType) -> String {
        return configurationManager.getDurationText(for: sensor)
    }
    
    public func setSampleCount(_ value: Int, for sensor: SensorType) {
        configurationManager.setSampleCount(value, for: sensor)
    }
    
    public func setDuration(_ value: Int, for sensor: SensorType) {
        configurationManager.setDuration(value, for: sensor)
    }
    
    public func setSampleCountText(_ text: String, for sensor: SensorType) {
        configurationManager.setSampleCountText(text, for: sensor)
    }
    
    public func setDurationText(_ text: String, for sensor: SensorType) {
        configurationManager.setDurationText(text, for: sensor)
    }
    
    // MARK: - Validation Methods
    
    public func validateSampleCount(_ text: String, for sensor: SensorType) -> Bool {
        let result = configurationManager.validateSampleCount(text, for: sensor)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    public func validateDuration(_ text: String, for sensor: SensorType) -> Bool {
        let result = configurationManager.validateDuration(text, for: sensor)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    // MARK: - Helper Methods
    
    public func getExpectedTime(for sensor: SensorType, sampleCount: Int) -> Double {
        return configurationManager.getExpectedTime(for: sensor, sampleCount: sampleCount)
    }
    
    public func getExpectedSamples(for sensor: SensorType, duration: Int) -> Int {
        return configurationManager.getExpectedSamples(for: sensor, duration: duration)
    }
    
    public func resetToDefaults() {
        configurationManager.resetToDefaults()
    }
    
    public func getConfigurationSummary() -> String {
        return configurationManager.getConfigurationSummary()
    }
    
    public func isSensorSelected(_ sensor: SensorType) -> Bool {
        return configurationManager.isSensorSelected(sensor)
    }
    
    /// 가속도계 모드를 업데이트합니다.
    /// 실시간 모니터링 중에 모드 변경을 콘솔에 즉시 반영합니다.
    public func updateAccelerometerMode(_ mode: AccelerometerMode) {
        configurationManager.updateAccelerometerMode(mode)
    }
    
    // MARK: - Private Methods
    
    /// SDK의 초기 상태를 ViewModel에 동기화합니다.
    private func syncInitialState() {
        selectedCollectionMode = configurationManager.selectedCollectionMode
        selectedSensors = configurationManager.selectedSensors
        isMonitoringActive = configurationManager.isMonitoringActive
        showRecordingChangeWarning = configurationManager.showRecordingChangeWarning
        pendingSensorSelection = configurationManager.pendingSensorSelection
        pendingConfigurationChange = configurationManager.pendingConfigurationChange
    }
}

// MARK: - BatchDataConfigurationManagerDelegate Implementation

extension BatchDataConfigurationViewModel {
    
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateCollectionMode mode: BatchDataConfigurationManager.CollectionMode) {
        selectedCollectionMode = mode
    }
    
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateSelectedSensors sensors: Set<SensorType>) {
        selectedSensors = sensors
    }
    
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateMonitoringState isActive: Bool) {
        isMonitoringActive = isActive
    }
    
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateShowRecordingChangeWarning show: Bool) {
        showRecordingChangeWarning = show
    }
    
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingSensorSelection sensors: Set<SensorType>?) {
        pendingSensorSelection = sensors
    }
    
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingConfigurationChange change: BatchDataConfigurationManager.PendingConfigurationChange?) {
        pendingConfigurationChange = change
    }
    
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateSensorConfigurations configurations: [SensorType: BatchDataConfigurationManager.SensorConfiguration]) {
        sensorConfigurations = configurations
    }
}

// MARK: - Type Aliases for Backward Compatibility

extension BatchDataConfigurationViewModel {
    typealias CollectionMode = BatchDataConfigurationManager.CollectionMode
} 