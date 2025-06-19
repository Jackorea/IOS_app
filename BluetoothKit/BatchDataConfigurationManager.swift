import Foundation

// MARK: - BatchDataConfigurationManagerDelegate Protocol

/// BatchDataConfigurationManager의 상태 변화를 알리는 델리게이트 프로토콜
internal protocol BatchDataConfigurationManagerDelegate: AnyObject {
    /// 수집 모드가 변경되었을 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateCollectionMode mode: BatchDataConfigurationManager.CollectionMode)
    /// 선택된 센서가 변경되었을 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateSelectedSensors sensors: Set<SensorType>)
    /// 모니터링 상태가 변경되었을 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateMonitoringState isActive: Bool)
    /// 경고 팝업 표시 상태가 변경되었을 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateShowRecordingChangeWarning show: Bool)
    /// 펜딩된 센서 선택이 변경되었을 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingSensorSelection sensors: Set<SensorType>?)
    /// 펜딩된 설정 변경이 변경되었을 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingConfigurationChange change: BatchDataConfigurationManager.PendingConfigurationChange?)
    /// 센서 설정이 변경되었을 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateSensorConfigurations configurations: [SensorType: BatchDataConfigurationManager.SensorConfiguration])
    /// 기록 중 센서 업데이트가 필요할 때 호출
    func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, needsUpdateRecordingSensors sensors: Set<SensorType>)
}

/// 배치 데이터 수집 설정을 관리하는 비즈니스 로직 클래스
/// UI 프레임워크에 의존하지 않는 순수한 비즈니스 로직을 제공합니다.
public class BatchDataConfigurationManager {
    
    // MARK: - Delegate
    
    /// 상태 변화를 받을 델리게이트
    internal weak var delegate: BatchDataConfigurationManagerDelegate?
    
    // MARK: - Types
    
    public enum CollectionMode: String, CaseIterable {
        case sampleCount = "샘플 수"
        case seconds = "초단위"
        case minutes = "분단위"
        
        public var displayName: String { rawValue }
    }
    
    /// 센서 설정을 관리하는 구조체
    public struct SensorConfiguration {
        public var sampleCount: Int
        public var seconds: Int
        public var minutes: Int
        public var sampleCountText: String
        public var secondsText: String
        public var minutesText: String
        
        public init(sampleCount: Int, seconds: Int, minutes: Int = 1) {
            self.sampleCount = sampleCount
            self.seconds = seconds
            self.minutes = minutes
            self.sampleCountText = "\(sampleCount)"
            self.secondsText = "\(seconds)"
            self.minutesText = "\(minutes)"
        }
        
        /// 기본값 설정
        public static func defaultConfiguration(for sensorType: SensorType) -> SensorConfiguration {
            switch sensorType {
            case .eeg:
                return SensorConfiguration(sampleCount: 250, seconds: 1, minutes: 1)
            case .ppg:
                return SensorConfiguration(sampleCount: 50, seconds: 1, minutes: 1)
            case .accelerometer:
                return SensorConfiguration(sampleCount: 30, seconds: 1, minutes: 1)
            case .battery:
                return SensorConfiguration(sampleCount: 1, seconds: 60, minutes: 1)
            }
        }
    }
    
    /// 유효성 검사 결과
    public struct ValidationResult {
        public let isValid: Bool
        public let message: String?
        
        public init(isValid: Bool, message: String? = nil) {
            self.isValid = isValid
            self.message = message
        }
    }
    
    /// 유효성 검사 범위 정의
    private enum ValidationRange {
        static let sampleCount = 1...100000
        static let seconds = 1...3600
        static let minutes = 1...60
    }
    
    /// 펜딩 중인 설정 변경 타입
    public enum PendingConfigurationChange {
        case sensorSelection(Set<SensorType>)
        case sampleCount(value: Int, sensor: SensorType)
        case seconds(value: Int, sensor: SensorType)
        case minutes(value: Int, sensor: SensorType)
    }
    
    // MARK: - Properties (델리게이트 패턴으로 변경)
    
    /// 선택된 수집 모드
    private(set) public var selectedCollectionMode: CollectionMode = .sampleCount {
        didSet {
            delegate?.batchDataConfigurationManager(self, didUpdateCollectionMode: selectedCollectionMode)
        }
    }
    
    /// 선택된 센서들
    private(set) public var selectedSensors: Set<SensorType> = [.eeg, .ppg, .accelerometer] {
        didSet {
            delegate?.batchDataConfigurationManager(self, didUpdateSelectedSensors: selectedSensors)
        }
    }
    
    /// 모니터링 활성화 상태
    private(set) public var isMonitoringActive = false {
        didSet {
            delegate?.batchDataConfigurationManager(self, didUpdateMonitoringState: isMonitoringActive)
        }
    }
    
    /// 경고 팝업 표시 상태
    private(set) public var showRecordingChangeWarning = false {
        didSet {
            delegate?.batchDataConfigurationManager(self, didUpdateShowRecordingChangeWarning: showRecordingChangeWarning)
        }
    }
    
    /// 펜딩된 센서 선택 (하위 호환성을 위해 유지)
    private(set) public var pendingSensorSelection: Set<SensorType>? {
        didSet {
            delegate?.batchDataConfigurationManager(self, didUpdatePendingSensorSelection: pendingSensorSelection)
        }
    }
    
    /// 펜딩된 설정 변경
    private(set) public var pendingConfigurationChange: PendingConfigurationChange? {
        didSet {
            delegate?.batchDataConfigurationManager(self, didUpdatePendingConfigurationChange: pendingConfigurationChange)
        }
    }
    
    /// 센서별 설정을 관리하는 Dictionary
    private var sensorConfigurations: [SensorType: SensorConfiguration] = [:] {
        didSet {
            delegate?.batchDataConfigurationManager(self, didUpdateSensorConfigurations: sensorConfigurations)
        }
    }
    
    // MARK: - Dependencies
    
    private let bluetoothKit: BluetoothKit
    private var batchDelegate: BatchDataConsoleLogger?
    
    // MARK: - Initialization
    
    public init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
        self.initializeDefaultConfigurations()
    }
    
    // MARK: - Internal Configuration Methods
    
    public func startMonitoring() {
        guard !self.selectedSensors.isEmpty else { return }
        
        // BluetoothKit에 센서 선택 전달
        self.bluetoothKit.setSelectedSensors(self.selectedSensors)
        
        // BluetoothKit의 모니터링 활성화
        self.bluetoothKit.enableMonitoring()
        
        self.setupBatchDelegate()
        self.configureAllSensors()
        self.isMonitoringActive = true
    }
    
    public func stopMonitoring() {
        // BluetoothKit에서 센서 선택을 비우고 모니터링 비활성화
        self.bluetoothKit.setSelectedSensors([])  // 모든 센서 수신 중단
        self.bluetoothKit.disableMonitoring()
        
        self.bluetoothKit.disableAllDataCollection()
        self.batchDelegate?.updateSelectedSensors(Set<SensorType>())
        self.bluetoothKit.batchDataDelegate = nil
        self.batchDelegate = nil
        self.isMonitoringActive = false
    }
    
    public func updateSensorSelection(_ sensors: Set<SensorType>) {
        // 기록 중이라면 경고 후 사용자 선택 요청
        if isMonitoringActive && self.bluetoothKit.isRecording {
            // UI에 경고 팝업 표시 요청
            self.pendingConfigurationChange = .sensorSelection(sensors)
            self.pendingSensorSelection = sensors  // 하위 호환성
            self.showRecordingChangeWarning = true
            return
        }
        
        // 기록 중이 아니라면 즉시 적용
        self.applySensorSelection(sensors)
    }
    
    /// 사용자가 경고 팝업에서 "기록 중지 후 변경"을 선택했을 때 호출
    public func confirmSensorChangeWithRecordingStop() {
        guard let pendingChange = self.pendingConfigurationChange else { return }
        
        // 기록 중지
        self.bluetoothKit.stopRecording()
        
        // 펜딩된 변경사항 적용
        switch pendingChange {
        case .sensorSelection(let sensors):
            self.applySensorSelection(sensors)
        case .sampleCount(let value, let sensor):
            self.applySampleCountChange(value, for: sensor)
        case .seconds(let value, let sensor):
            self.applySecondsChange(value, for: sensor)
        case .minutes(let value, let sensor):
            self.applyMinutesChange(value, for: sensor)
        }
        
        // 임시 저장 정리
        self.pendingConfigurationChange = nil
        self.pendingSensorSelection = nil
        self.showRecordingChangeWarning = false
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출
    public func cancelSensorChange() {
        // 임시 저장 정리
        self.pendingConfigurationChange = nil
        self.pendingSensorSelection = nil
        self.showRecordingChangeWarning = false
    }
    
    /// 실제 센서 선택 적용 로직
    private func applySensorSelection(_ sensors: Set<SensorType>) {
        self.selectedSensors = sensors
        
        // 모니터링 상태에 관계없이 BatchDataConsoleLogger에 센서 선택 변경사항 반영
        // batchDelegate가 없으면 미리 생성
        if self.batchDelegate == nil {
            self.batchDelegate = BatchDataConsoleLogger()
            self.bluetoothKit.batchDataDelegate = self.batchDelegate
        }
        
        self.batchDelegate?.updateSelectedSensors(self.selectedSensors)
        
        // 모니터링 중이라면 BluetoothKit에서도 센서 데이터 수집 재설정
        if isMonitoringActive {
            // BluetoothKit에서도 센서 데이터 수집 재설정
            self.reconfigureSensorsForSelection()
        }
    }
    
    /// 수집 모드 업데이트
    public func updateCollectionMode(_ mode: CollectionMode) {
        guard selectedCollectionMode != mode else { return }
        selectedCollectionMode = mode
        
        // 모니터링 중이라면 설정 재적용
        if isMonitoringActive {
            configureAllSensors()
        }
    }
    
    // MARK: - Sensor Configuration Access
    
    /// 특정 센서의 샘플 수를 반환
    public func getSampleCount(for sensor: SensorType) -> Int {
        return self.sensorConfigurations[sensor]?.sampleCount ?? SensorConfiguration.defaultConfiguration(for: sensor).sampleCount
    }
    
    /// 특정 센서의 시간(초)을 반환
    public func getSeconds(for sensor: SensorType) -> Int {
        return self.sensorConfigurations[sensor]?.seconds ?? SensorConfiguration.defaultConfiguration(for: sensor).seconds
    }
    
    /// 특정 센서의 분(분)을 반환
    public func getMinutes(for sensor: SensorType) -> Int {
        return self.sensorConfigurations[sensor]?.minutes ?? SensorConfiguration.defaultConfiguration(for: sensor).minutes
    }
    
    /// 특정 센서의 샘플 수 텍스트를 반환
    public func getSampleCountText(for sensor: SensorType) -> String {
        return self.sensorConfigurations[sensor]?.sampleCountText ?? "\(self.getSampleCount(for: sensor))"
    }
    
    /// 특정 센서의 시간 텍스트를 반환
    public func getSecondsText(for sensor: SensorType) -> String {
        return self.sensorConfigurations[sensor]?.secondsText ?? "\(self.getSeconds(for: sensor))"
    }
    
    /// 특정 센서의 분 텍스트를 반환
    public func getMinutesText(for sensor: SensorType) -> String {
        return self.sensorConfigurations[sensor]?.minutesText ?? "\(self.getMinutes(for: sensor))"
    }
    
    /// 특정 센서의 샘플 수를 설정
    public func setSampleCount(_ value: Int, for sensor: SensorType) {
        // 기록 중이라면 경고 후 사용자 선택 요청
        if isMonitoringActive && self.bluetoothKit.isRecording {
            // UI에 경고 팝업 표시 요청 (설정 변경)
            self.pendingConfigurationChange = .sampleCount(value: value, sensor: sensor)
            self.showRecordingChangeWarning = true
            return
        }
        
        // 기록 중이 아니라면 즉시 적용
        self.applySampleCountChange(value, for: sensor)
    }
    
    /// 특정 센서의 시간을 설정
    public func setSeconds(_ value: Int, for sensor: SensorType) {
        // 기록 중이라면 경고 후 사용자 선택 요청
        if isMonitoringActive && self.bluetoothKit.isRecording {
            // UI에 경고 팝업 표시 요청 (설정 변경)
            self.pendingConfigurationChange = .seconds(value: value, sensor: sensor)
            self.showRecordingChangeWarning = true
            return
        }
        
        // 기록 중이 아니라면 즉시 적용
        self.applySecondsChange(value, for: sensor)
    }
    
    /// 특정 센서의 분을 설정
    public func setMinutes(_ value: Int, for sensor: SensorType) {
        // 기록 중이라면 경고 후 사용자 선택 요청
        if isMonitoringActive && self.bluetoothKit.isRecording {
            // UI에 경고 팝업 표시 요청 (설정 변경)
            self.pendingConfigurationChange = .minutes(value: value, sensor: sensor)
            self.showRecordingChangeWarning = true
            return
        }
        
        // 기록 중이 아니라면 즉시 적용
        self.applyMinutesChange(value, for: sensor)
    }
    
    /// 특정 센서의 샘플 수 텍스트를 설정
    public func setSampleCountText(_ text: String, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.sampleCountText = text
    }
    
    /// 특정 센서의 시간 텍스트를 설정
    public func setSecondsText(_ text: String, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.secondsText = text
    }
    
    /// 특정 센서의 분 텍스트를 설정
    public func setMinutesText(_ text: String, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.minutesText = text
    }
    
    // MARK: - Validation Methods
    
    /// 샘플 수 유효성 검사
    public func validateSampleCount(_ text: String, for sensor: SensorType) -> ValidationResult {
        return self.validateValue(text, for: sensor, valueType: .sampleCount, range: ValidationRange.sampleCount)
    }
    
    /// 시간 유효성 검사
    public func validateSeconds(_ text: String, for sensor: SensorType) -> ValidationResult {
        return self.validateValue(text, for: sensor, valueType: .seconds, range: ValidationRange.seconds)
    }
    
    /// 분 유효성 검사
    public func validateMinutes(_ text: String, for sensor: SensorType) -> ValidationResult {
        return self.validateValue(text, for: sensor, valueType: .minutes, range: ValidationRange.minutes)
    }
    
    // MARK: - Helper Methods
    
    public func getExpectedTime(for sensor: SensorType, sampleCount: Int) -> Double {
        return sensor.expectedTime(for: sampleCount)
    }
    
    public func getExpectedSamples(for sensor: SensorType, seconds: Int) -> Int {
        return sensor.expectedSamples(for: TimeInterval(seconds))
    }
    
    /// 특정 센서와 분에 대한 예상 샘플 수를 반환합니다.
    public func getExpectedSamples(for sensor: SensorType, minutes: Int) -> Int {
        return sensor.expectedSamples(for: TimeInterval(minutes * 60))
    }
    
    /// 특정 센서와 샘플 수에 대한 예상 분을 반환합니다.
    public func getExpectedMinutes(for sensor: SensorType, sampleCount: Int) -> Double {
        return sensor.expectedTime(for: sampleCount) / 60.0
    }
    
    /// 모든 센서 설정을 기본값으로 리셋
    public func resetToDefaults() {
        self.initializeDefaultConfigurations()
    }
    
    /// 설정 상태 요약 반환
    public func getConfigurationSummary() -> String {
        let mode = self.selectedCollectionMode.displayName
        let sensors = self.selectedSensors.map { $0.displayName }.joined(separator: ", ")
        return "모드: \(mode), 센서: \(sensors)"
    }
    
    /// 특정 센서가 선택되었는지 확인
    public func isSensorSelected(_ sensor: SensorType) -> Bool {
        return self.selectedSensors.contains(sensor)
    }
    
    /// 가속도계 모드를 업데이트합니다.
    /// 모니터링 중일 때 실시간으로 콘솔 출력 모드를 변경할 수 있습니다.
    public func updateAccelerometerMode(_ mode: AccelerometerMode) {
        // 모니터링 중이고 batchDelegate가 있다면 즉시 모드 업데이트
        if isMonitoringActive, let delegate = self.batchDelegate {
            delegate.updateAccelerometerMode(mode)
        }
    }
    
    // MARK: - Private Methods
    
    private enum ValueType {
        case sampleCount
        case seconds
        case minutes
    }
    
    /// 기본 설정 초기화
    private func initializeDefaultConfigurations() {
        for sensorType in SensorType.allCases {
            self.sensorConfigurations[sensorType] = SensorConfiguration.defaultConfiguration(for: sensorType)
        }
    }
    
    /// 배치 델리게이트 설정
    private func setupBatchDelegate() {
        if self.batchDelegate == nil {
            self.batchDelegate = BatchDataConsoleLogger()
            self.bluetoothKit.batchDataDelegate = self.batchDelegate
        }
        
        self.batchDelegate?.updateSelectedSensors(self.selectedSensors)
        // 현재 가속도계 모드도 함께 전달
        self.batchDelegate?.updateAccelerometerMode(self.bluetoothKit.accelerometerMode)
    }
    
    /// 모든 센서 설정 적용
    private func configureAllSensors() {
        for sensorType in SensorType.allCases {
            if self.selectedSensors.contains(sensorType) {
                self.configureSensor(sensorType, isInitial: true)
            } else {
                self.bluetoothKit.disableDataCollection(for: sensorType)
            }
        }
    }
    
    /// 변경사항 적용
    private func applyChanges() {
        self.setupBatchDelegate()
        
        if self.bluetoothKit.isRecording {
            // delegate를 통해 BluetoothKit에 센서 업데이트 요청
            delegate?.batchDataConfigurationManager(self, needsUpdateRecordingSensors: self.selectedSensors)
        }
        
        self.configureAllSensors()
    }
    
    /// 특정 센서 설정
    private func configureSensor(_ sensor: SensorType, isInitial: Bool = false) {
        switch self.selectedCollectionMode {
        case .sampleCount:
            let sampleCount = self.getSampleCount(for: sensor)
            self.bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensor)
            
        case .seconds:
            let seconds = self.getSeconds(for: sensor)
            self.bluetoothKit.setDataCollection(timeInterval: TimeInterval(seconds), for: sensor)
        case .minutes:
            let minutes = self.getMinutes(for: sensor)
            self.bluetoothKit.setDataCollection(timeInterval: TimeInterval(minutes * 60), for: sensor)
        }
    }
    
    /// 샘플 수 업데이트
    private func updateSampleCount(_ value: Int, for sensor: SensorType, originalValue: Int) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.sampleCount = value
        if value != originalValue {
            self.sensorConfigurations[sensor]?.sampleCountText = "\(value)"
        }
    }
    
    /// 시간 업데이트
    private func updateSeconds(_ value: Int, for sensor: SensorType, originalValue: Int) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.seconds = value
        if value != originalValue {
            self.sensorConfigurations[sensor]?.secondsText = "\(value)"
        }
    }
    
    /// 분 업데이트
    private func updateMinutes(_ value: Int, for sensor: SensorType, originalValue: Int) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.minutes = value
        if value != originalValue {
            self.sensorConfigurations[sensor]?.minutesText = "\(value)"
        }
    }
    
    /// 센서 선택 변경에 따라 BluetoothKit의 데이터 수집을 재설정합니다.
    private func reconfigureSensorsForSelection() {
        for sensorType in SensorType.allCases {
            if self.selectedSensors.contains(sensorType) {
                // 선택된 센서: 데이터 수집 재활성화
                self.configureSensor(sensorType, isInitial: false)
            } else {
                // 선택 해제된 센서: 데이터 수집 비활성화
                self.bluetoothKit.disableDataCollection(for: sensorType)
            }
        }
    }
    
    /// 샘플 수 변경 적용
    private func applySampleCountChange(_ value: Int, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.sampleCount = value
        self.sensorConfigurations[sensor]?.sampleCountText = "\(value)"
        
        // 모니터링 중이라면 센서 재설정
        if isMonitoringActive && self.selectedSensors.contains(sensor) {
            self.configureSensor(sensor, isInitial: false)
        }
    }
    
    /// 시간 변경 적용
    private func applySecondsChange(_ value: Int, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.seconds = value
        self.sensorConfigurations[sensor]?.secondsText = "\(value)"
        
        // 모니터링 중이라면 센서 재설정
        if isMonitoringActive && self.selectedSensors.contains(sensor) {
            self.configureSensor(sensor, isInitial: false)
        }
    }
    
    /// 분 변경 적용
    private func applyMinutesChange(_ value: Int, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.minutes = value
        self.sensorConfigurations[sensor]?.minutesText = "\(value)"
        
        // 모니터링 중이라면 센서 재설정
        if isMonitoringActive && self.selectedSensors.contains(sensor) {
            self.configureSensor(sensor, isInitial: false)
        }
    }
    
    /// 센서 설정이 존재하는지 확인하고 없으면 생성
    private func ensureConfigurationExists(for sensor: SensorType) {
        if self.sensorConfigurations[sensor] == nil {
            self.sensorConfigurations[sensor] = SensorConfiguration.defaultConfiguration(for: sensor)
        }
    }
    
    /// 값 유효성 검사 및 업데이트
    private func validateValue(_ text: String, for sensor: SensorType, valueType: ValueType, range: ClosedRange<Int>) -> ValidationResult {
        guard let value = Int(text), value > 0 else {
            if !text.isEmpty {
                return ValidationResult(isValid: false, message: "유효한 숫자를 입력해주세요")
            }
            return ValidationResult(isValid: false)
        }
        
        let clampedValue = max(range.lowerBound, min(value, range.upperBound))
        
        switch valueType {
        case .sampleCount:
            self.updateSampleCount(clampedValue, for: sensor, originalValue: value)
        case .seconds:
            self.updateSeconds(clampedValue, for: sensor, originalValue: value)
        case .minutes:
            self.updateMinutes(clampedValue, for: sensor, originalValue: value)
        }
        
        return ValidationResult(isValid: true)
    }
} 