import SwiftUI
import BluetoothKit
import Combine

/// 배치 데이터 수집 설정을 관리하는 ViewModel (UI 레이어)
/// 비즈니스 로직은 BatchDataConfigurationManager에 위임하고, UI 관련 기능만 담당
@MainActor
class BatchDataConfigurationViewModel: ObservableObject {
    
    // MARK: - UI State Properties
    
    @Published var showValidationError: Bool = false
    @Published var validationMessage: String = ""
    
    // 경고 팝업 관련 상태 (UI에서 바인딩 가능하도록 @Published로 설정)
    @Published var showRecordingChangeWarning: Bool = false
    @Published var pendingSensorSelection: Set<SensorType>? = nil
    
    // MARK: - Business Logic Manager
    
    private let configurationManager: BatchDataConfigurationManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Delegation Properties (Manager의 Published 속성들을 노출)
    
    var selectedCollectionMode: BatchDataConfigurationManager.CollectionMode {
        get { configurationManager.selectedCollectionMode }
        set { configurationManager.selectedCollectionMode = newValue }
    }
    
    var selectedSensors: Set<SensorType> {
        get { configurationManager.selectedSensors }
        set { configurationManager.selectedSensors = newValue }
    }
    
    var isConfigured: Bool {
        configurationManager.isConfigured
    }
    
    // MARK: - Initialization
    
    init(bluetoothKit: BluetoothKit) {
        self.configurationManager = BatchDataConfigurationManager(bluetoothKit: bluetoothKit)
        setupBindings()
    }
    
    // MARK: - Configuration Methods (Manager에 위임)
    
    func applyInitialConfiguration() {
        configurationManager.applyInitialConfiguration()
    }
    
    func removeConfiguration() {
        configurationManager.removeConfiguration()
    }
    
    func updateSensorSelection(_ sensors: Set<SensorType>) {
        configurationManager.updateSensorSelection(sensors)
    }
    
    func updateCollectionMode(_ mode: BatchDataConfigurationManager.CollectionMode) {
        configurationManager.updateCollectionMode(mode)
    }
    
    // MARK: - Warning Popup Methods
    
    /// 사용자가 경고 팝업에서 "기록 중지 후 변경"을 선택했을 때 호출
    func confirmSensorChangeWithRecordingStop() {
        configurationManager.confirmSensorChangeWithRecordingStop()
        // ViewModel 상태도 즉시 업데이트
        showRecordingChangeWarning = false
        pendingSensorSelection = nil
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출
    func cancelSensorChange() {
        configurationManager.cancelSensorChange()
        // ViewModel 상태도 즉시 업데이트
        showRecordingChangeWarning = false
        pendingSensorSelection = nil
    }
    
    // MARK: - Sensor Configuration Access (Manager에 위임)
    
    func getSampleCount(for sensor: SensorType) -> Int {
        return configurationManager.getSampleCount(for: sensor)
    }
    
    func getDuration(for sensor: SensorType) -> Int {
        return configurationManager.getDuration(for: sensor)
    }
    
    func getSampleCountText(for sensor: SensorType) -> String {
        return configurationManager.getSampleCountText(for: sensor)
    }
    
    func getDurationText(for sensor: SensorType) -> String {
        return configurationManager.getDurationText(for: sensor)
    }
    
    func setSampleCount(_ value: Int, for sensor: SensorType) {
        configurationManager.setSampleCount(value, for: sensor)
    }
    
    func setDuration(_ value: Int, for sensor: SensorType) {
        configurationManager.setDuration(value, for: sensor)
    }
    
    func setSampleCountText(_ text: String, for sensor: SensorType) {
        configurationManager.setSampleCountText(text, for: sensor)
    }
    
    func setDurationText(_ text: String, for sensor: SensorType) {
        configurationManager.setDurationText(text, for: sensor)
    }
    
    // MARK: - Legacy Computed Properties (기존 View 호환성을 위해 유지)
    
    var eegSampleCount: Int {
        get { getSampleCount(for: .eeg) }
        set { setSampleCount(newValue, for: .eeg) }
    }
    
    var ppgSampleCount: Int {
        get { getSampleCount(for: .ppg) }
        set { setSampleCount(newValue, for: .ppg) }
    }
    
    var accelerometerSampleCount: Int {
        get { getSampleCount(for: .accelerometer) }
        set { setSampleCount(newValue, for: .accelerometer) }
    }
    
    var eegDurationSeconds: Int {
        get { getDuration(for: .eeg) }
        set { setDuration(newValue, for: .eeg) }
    }
    
    var ppgDurationSeconds: Int {
        get { getDuration(for: .ppg) }
        set { setDuration(newValue, for: .ppg) }
    }
    
    var accelerometerDurationSeconds: Int {
        get { getDuration(for: .accelerometer) }
        set { setDuration(newValue, for: .accelerometer) }
    }
    
    var eegSampleCountText: String {
        get { getSampleCountText(for: .eeg) }
        set { setSampleCountText(newValue, for: .eeg) }
    }
    
    var ppgSampleCountText: String {
        get { getSampleCountText(for: .ppg) }
        set { setSampleCountText(newValue, for: .ppg) }
    }
    
    var accelerometerSampleCountText: String {
        get { getSampleCountText(for: .accelerometer) }
        set { setSampleCountText(newValue, for: .accelerometer) }
    }
    
    var eegDurationText: String {
        get { getDurationText(for: .eeg) }
        set { setDurationText(newValue, for: .eeg) }
    }
    
    var ppgDurationText: String {
        get { getDurationText(for: .ppg) }
        set { setDurationText(newValue, for: .ppg) }
    }
    
    var accelerometerDurationText: String {
        get { getDurationText(for: .accelerometer) }
        set { setDurationText(newValue, for: .accelerometer) }
    }
    
    // MARK: - Validation Methods (UI 에러 상태 업데이트 포함)
    
    func validateSampleCount(_ text: String, for sensor: SensorType) -> Bool {
        let result = configurationManager.validateSampleCount(text, for: sensor)
        updateValidationState(result)
        return result.isValid
    }
    
    func validateDuration(_ text: String, for sensor: SensorType) -> Bool {
        let result = configurationManager.validateDuration(text, for: sensor)
        updateValidationState(result)
        return result.isValid
    }
    
    // MARK: - Helper Methods (Manager에 위임)
    
    func getExpectedTime(for sensor: SensorType, sampleCount: Int) -> Double {
        return configurationManager.getExpectedTime(for: sensor, sampleCount: sampleCount)
    }
    
    func getExpectedSamples(for sensor: SensorType, duration: Int) -> Int {
        return configurationManager.getExpectedSamples(for: sensor, duration: duration)
    }
    
    func resetToDefaults() {
        configurationManager.resetToDefaults()
    }
    
    func getConfigurationSummary() -> String {
        return configurationManager.getConfigurationSummary()
    }
    
    func isSensorSelected(_ sensor: SensorType) -> Bool {
        return configurationManager.isSensorSelected(sensor)
    }
    
    // MARK: - Private Methods
    
    /// Manager의 Published 속성들과 UI 바인딩 설정
    private func setupBindings() {
        // Manager의 상태 변경을 UI에 반영
        configurationManager.$selectedCollectionMode
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        configurationManager.$selectedSensors
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        configurationManager.$isConfigured
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // 경고 팝업 상태 바인딩
        configurationManager.$showRecordingChangeWarning
            .sink { [weak self] newValue in
                self?.showRecordingChangeWarning = newValue
            }
            .store(in: &cancellables)
        
        configurationManager.$pendingSensorSelection
            .sink { [weak self] newValue in
                self?.pendingSensorSelection = newValue
            }
            .store(in: &cancellables)
    }
    
    /// 유효성 검사 결과를 UI 상태에 반영
    private func updateValidationState(_ result: BatchDataConfigurationManager.ValidationResult) {
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
    }
}

// MARK: - Type Aliases for Backward Compatibility

extension BatchDataConfigurationViewModel {
    typealias CollectionMode = BatchDataConfigurationManager.CollectionMode
} 