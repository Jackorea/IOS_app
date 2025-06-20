import SwiftUI
import BluetoothKit // 어댑터 역할을 하므로 SDK import 필요
import Combine

/// BatchDataConfigurationManager를 SwiftUI에서 사용할 수 있도록 래핑하는 ViewModel
/// SDK의 순수 비즈니스 로직과 UI를 연결하는 어댑터 역할을 합니다.
@MainActor
class BatchDataConfigurationViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI 바인딩용) - SensorKind 사용
    
    @Published public var selectedCollectionMode: CollectionModeKind = .sampleCount
    @Published public var selectedSensors: Set<SensorKind> = [.eeg, .ppg, .accelerometer]
    @Published public var isMonitoringActive = false
    @Published public var showRecordingChangeWarning = false
    @Published public var pendingSensorSelection: Set<SensorKind>?
    @Published public var pendingConfigurationChange: BatchDataConfigurationManager.PendingConfigurationChange?
    @Published public var sensorConfigurations: [SensorKind: BatchDataConfigurationManager.SensorConfiguration] = [:]
    
    // UI 전용 상태
    @Published public var showValidationError: Bool = false
    @Published public var validationMessage: String = ""
    
    // MARK: - SDK Instance
    
    /// 통합된 BluetoothKit 인스턴스 (단일 진입점) - internal로 캡슐화
    private let bluetoothKit: BluetoothKit
    
    // MARK: - Initialization
    
    /// 새로운 BatchDataConfigurationViewModel 인스턴스를 생성합니다.
    public init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
        
        // 초기 상태 동기화
        syncInitialState()
    }
    
    // MARK: - Public Interface (SensorKind 어댑터 메서드들)
    
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
    
    /// 센서 선택을 업데이트합니다. - SensorKind를 SensorType으로 변환
    public func updateSensorSelection(_ sensors: Set<SensorKind>) {
        let sdkSensors = Set(sensors.map { $0.sdkType })
        bluetoothKit.updateBatchSensorSelection(sdkSensors)
        // UI 동기화를 위해 로컬 상태도 업데이트
        selectedSensors = sensors
    }
    
    /// 수집 모드를 업데이트합니다.
    public func updateCollectionMode(_ mode: CollectionModeKind) {
        bluetoothKit.updateBatchCollectionMode(mode.sdkMode)
    }
    
    /// 사용자가 경고 팝업에서 "기록 중지 후 변경"을 선택했을 때 호출
    public func confirmSensorChangeWithRecordingStop() {
        bluetoothKit.confirmBatchSensorChangeWithRecordingStop()
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출
    public func cancelSensorChange() {
        bluetoothKit.cancelBatchSensorChange()
    }
    
    // MARK: - Sensor Configuration Access - SensorKind 어댑터 메서드들
    
    public func getSampleCount(for sensor: SensorKind) -> Int {
        return bluetoothKit.getBatchSampleCount(for: sensor.sdkType)
    }
    
    public func getSeconds(for sensor: SensorKind) -> Int {
        return bluetoothKit.getBatchSeconds(for: sensor.sdkType)
    }
    
    public func getSampleCountText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchSampleCountText(for: sensor.sdkType)
    }
    
    public func getSecondsText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchSecondsText(for: sensor.sdkType)
    }
    
    public func getMinutes(for sensor: SensorKind) -> Int {
        return bluetoothKit.getBatchMinutes(for: sensor.sdkType)
    }
    
    public func getMinutesText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchMinutesText(for: sensor.sdkType)
    }
    
    public func setSampleCount(_ value: Int, for sensor: SensorKind) {
        bluetoothKit.setBatchSampleCount(value, for: sensor.sdkType)
    }
    
    public func setSeconds(_ value: Int, for sensor: SensorKind) {
        bluetoothKit.setBatchSeconds(value, for: sensor.sdkType)
    }
    
    public func setMinutes(_ value: Int, for sensor: SensorKind) {
        bluetoothKit.setBatchMinutes(value, for: sensor.sdkType)
    }
    
    public func setSampleCountText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchSampleCountText(text, for: sensor.sdkType)
    }
    
    public func setSecondsText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchSecondsText(text, for: sensor.sdkType)
    }
    
    public func setMinutesText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchMinutesText(text, for: sensor.sdkType)
    }
    
    // MARK: - Validation Methods - SensorKind 어댑터 메서드들
    
    public func validateSampleCount(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchSampleCount(text, for: sensor.sdkType)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    public func validateSeconds(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchSeconds(text, for: sensor.sdkType)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    public func validateMinutes(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchMinutes(text, for: sensor.sdkType)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    // MARK: - Helper Methods - SensorKind 어댑터 메서드들
    
    public func getExpectedTime(for sensor: SensorKind, sampleCount: Int) -> Double {
        return bluetoothKit.getBatchExpectedTime(for: sensor.sdkType, sampleCount: sampleCount)
    }
    
    public func getExpectedSamples(for sensor: SensorKind, seconds: Int) -> Int {
        return bluetoothKit.getBatchExpectedSamples(for: sensor.sdkType, seconds: seconds)
    }
    
    public func getExpectedSamplesForMinutes(for sensor: SensorKind, minutes: Int) -> Int {
        return bluetoothKit.getBatchExpectedSamplesForMinutes(for: sensor.sdkType, minutes: minutes)
    }
    
    public func getExpectedMinutes(for sensor: SensorKind, sampleCount: Int) -> Double {
        return bluetoothKit.getBatchExpectedMinutes(for: sensor.sdkType, sampleCount: sampleCount)
    }
    
    public func resetToDefaults() {
        bluetoothKit.resetBatchToDefaults()
    }
    
    public func getConfigurationSummary() -> String {
        return bluetoothKit.getBatchConfigurationSummary()
    }
    
    public func isSensorSelected(_ sensor: SensorKind) -> Bool {
        return bluetoothKit.isBatchSensorSelected(sensor.sdkType)
    }
    
    /// 가속도계 모드를 업데이트합니다. - AccelMode 어댑터 사용
    /// 실시간 모니터링 중에 모드 변경을 콘솔에 즉시 반영합니다.
    public func updateAccelerometerMode(_ mode: AccelMode) {
        bluetoothKit.updateBatchAccelerometerMode(mode.sdkMode)
    }
    
    // MARK: - Private Methods
    
    /// BluetoothKit의 초기 상태를 ViewModel에 동기화합니다. - SensorKind 변환 적용
    private func syncInitialState() {
        selectedCollectionMode = CollectionModeKind.from(bluetoothKit.batchSelectedCollectionMode)
        selectedSensors = Set(bluetoothKit.batchSelectedSensors.map { SensorKind.from($0) })
        isMonitoringActive = bluetoothKit.isBatchMonitoringActive
        showRecordingChangeWarning = bluetoothKit.showBatchRecordingChangeWarning
        
        // 타입 어노테이션 명시적 지정
        if let pendingSelection = bluetoothKit.batchPendingSensorSelection {
            pendingSensorSelection = Set(pendingSelection.map { SensorKind.from($0) })
        } else {
            pendingSensorSelection = nil
        }
        
        // 나머지 syncInitialState 구현...
    }
} 