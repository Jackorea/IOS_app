import Foundation

// MARK: - BatchDataConfigurationManager Delegate Protocol

/// BatchDataConfigurationManager의 상태 변경을 알리는 델리게이트 프로토콜
public protocol BatchDataConfigurationManagerDelegate: AnyObject {
    func configurationManager(_ manager: BatchDataConfigurationManager, didUpdateCollectionMode mode: BatchDataConfigurationManager.CollectionMode)
    func configurationManager(_ manager: BatchDataConfigurationManager, didUpdateSelectedSensors sensors: Set<SensorType>)
    func configurationManager(_ manager: BatchDataConfigurationManager, didUpdateMonitoringState isActive: Bool)
    func configurationManager(_ manager: BatchDataConfigurationManager, didUpdateRecordingChangeWarning show: Bool)
    func configurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingSensorSelection sensors: Set<SensorType>?)
    func configurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingConfigurationChange change: BatchDataConfigurationManager.PendingConfigurationChange?)
}

/// 배치 데이터 수집 설정을 관리하는 비즈니스 로직 클래스
/// UI 프레임워크에 의존하지 않는 순수한 비즈니스 로직을 제공합니다.
public class BatchDataConfigurationManager {
    
    // MARK: - Delegate
    
    /// 상태 변경을 받을 델리게이트
    public weak var delegate: BatchDataConfigurationManagerDelegate?
    
    // MARK: - Types
    
    public enum CollectionMode: String, CaseIterable {
        case sampleCount = "샘플 수"
        case duration = "시간 (초)"
        
        public var displayName: String { rawValue }
    }
    
    /// 센서 설정을 관리하는 구조체
    public struct SensorConfiguration {
        public var sampleCount: Int
        public var duration: Int
        public var sampleCountText: String
        public var durationText: String
        
        public init(sampleCount: Int, duration: Int) {
            self.sampleCount = sampleCount
            self.duration = duration
            self.sampleCountText = "\(sampleCount)"
            self.durationText = "\(duration)"
        }
        
        /// 기본값 설정
        public static func defaultConfiguration(for sensorType: SensorType) -> SensorConfiguration {
            switch sensorType {
            case .eeg:
                return SensorConfiguration(sampleCount: 250, duration: 1)
            case .ppg:
                return SensorConfiguration(sampleCount: 50, duration: 1)
            case .accelerometer:
                return SensorConfiguration(sampleCount: 30, duration: 1)
            case .battery:
                return SensorConfiguration(sampleCount: 1, duration: 60)
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
        static let duration = 1...3600
    }
    
    /// 펜딩 중인 설정 변경 타입
    public enum PendingConfigurationChange {
        case sensorSelection(Set<SensorType>)
        case sampleCount(value: Int, sensor: SensorType)
        case duration(value: Int, sensor: SensorType)
    }
    
    // MARK: - Properties (UI 프레임워크 의존성 제거)
    
    private var _selectedCollectionMode: CollectionMode = .sampleCount
    public var selectedCollectionMode: CollectionMode {
        get { _selectedCollectionMode }
        set {
            _selectedCollectionMode = newValue
            delegate?.configurationManager(self, didUpdateCollectionMode: newValue)
        }
    }
    
    private var _selectedSensors: Set<SensorType> = [.eeg, .ppg, .accelerometer]
    public var selectedSensors: Set<SensorType> {
        get { _selectedSensors }
        set {
            _selectedSensors = newValue
            delegate?.configurationManager(self, didUpdateSelectedSensors: newValue)
        }
    }
    
    private var _isMonitoringActive = false  // 설정 완료 → 모니터링 활성화로 변경
    public var isMonitoringActive: Bool {
        get { _isMonitoringActive }
        set {
            _isMonitoringActive = newValue
            delegate?.configurationManager(self, didUpdateMonitoringState: newValue)
        }
    }
    
    // 경고 팝업 관련 상태
    private var _showRecordingChangeWarning = false
    public var showRecordingChangeWarning: Bool {
        get { _showRecordingChangeWarning }
        set {
            _showRecordingChangeWarning = newValue
            delegate?.configurationManager(self, didUpdateRecordingChangeWarning: newValue)
        }
    }
    
    private var _pendingSensorSelection: Set<SensorType>?  // 하위 호환성을 위해 유지
    public var pendingSensorSelection: Set<SensorType>? {
        get { _pendingSensorSelection }
        set {
            _pendingSensorSelection = newValue
            delegate?.configurationManager(self, didUpdatePendingSensorSelection: newValue)
        }
    }
    
    private var _pendingConfigurationChange: PendingConfigurationChange?
    public var pendingConfigurationChange: PendingConfigurationChange? {
        get { _pendingConfigurationChange }
        set {
            _pendingConfigurationChange = newValue
            delegate?.configurationManager(self, didUpdatePendingConfigurationChange: newValue)
        }
    }
    
    /// 센서별 설정을 관리하는 Dictionary
    private var sensorConfigurations: [SensorType: SensorConfiguration] = [:]
    
    // MARK: - Dependencies
    
    private let bluetoothKit: BluetoothKit
    private var batchDelegate: BatchDataConsoleLogger?
    
    // MARK: - Initialization
    
    public init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
        self.initializeDefaultConfigurations()
    }
    
    // MARK: - Public Configuration Methods
    
    public func startMonitoring() {
        guard !self.selectedSensors.isEmpty else { return }
        
        self.setupBatchDelegate()
        self.configureAllSensors()
        
        // ⭐️ 중요: BluetoothKit에 선택된 센서를 설정하여 BLE notify 활성화
        self.bluetoothKit.setSelectedSensors(self.selectedSensors)
        
        self.isMonitoringActive = true
        print("✅ 센서 모니터링 시작 - 선택된 센서: \(self.selectedSensors.map { $0.displayName }.joined(separator: ", "))")
        print("📡 BLE Notify 활성화: \(self.selectedSensors.map { $0.displayName }.joined(separator: ", "))")
    }
    
    public func stopMonitoring() {
        self.bluetoothKit.disableAllDataCollection()
        self.batchDelegate?.updateSelectedSensors(Set<SensorType>())
        self.bluetoothKit.batchDataDelegate = nil
        self.batchDelegate = nil
        
        // ⭐️ 중요: BluetoothKit에서 모든 센서의 BLE notify 비활성화 (배터리 제외)
        self.bluetoothKit.setSelectedSensors(Set<SensorType>())
        
        self.isMonitoringActive = false
        print("❌ 센서 모니터링 중지")
        print("📡 BLE Notify 비활성화: 모든 센서 (배터리 제외)")
    }
    
    public func updateSensorSelection(_ sensors: Set<SensorType>) {
        // 기록 중이라면 경고 후 사용자 선택 요청
        if isMonitoringActive && self.bluetoothKit.isRecording {
            print("⚠️ 기록 중 센서 선택 변경 시도 감지")
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
        
        print("✅ 사용자 확인: 기록 중지 후 설정 변경")
        
        // 기록 중지
        self.bluetoothKit.stopRecording()
        
        // 펜딩된 변경사항 적용
        switch pendingChange {
        case .sensorSelection(let sensors):
            self.applySensorSelection(sensors)
        case .sampleCount(let value, let sensor):
            self.applySampleCountChange(value, for: sensor)
        case .duration(let value, let sensor):
            self.applyDurationChange(value, for: sensor)
        }
        
        // 임시 저장 정리
        self.pendingConfigurationChange = nil
        self.pendingSensorSelection = nil
        self.showRecordingChangeWarning = false
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출
    public func cancelSensorChange() {
        print("❌ 사용자 취소: 설정 변경 취소")
        
        // 임시 저장 정리
        self.pendingConfigurationChange = nil
        self.pendingSensorSelection = nil
        self.showRecordingChangeWarning = false
    }
    
    /// 실제 센서 선택 적용 로직
    private func applySensorSelection(_ sensors: Set<SensorType>) {
        self.selectedSensors = sensors
        print("🔄 센서 선택 업데이트: \(sensors.map { $0.displayName }.joined(separator: ", "))")
        
        // 즉시 BatchDataConsoleLogger에 센서 선택 변경사항 반영
        if isMonitoringActive {
            self.batchDelegate?.updateSelectedSensors(self.selectedSensors)
            print("📝 콘솔 출력 센서 즉시 업데이트: \(self.selectedSensors.map { $0.displayName }.joined(separator: ", "))")
            
            // BluetoothKit에서도 센서 데이터 수집 재설정
            self.reconfigureSensorsForSelection()
        }
    }
    
    public func updateCollectionMode(_ mode: CollectionMode) {
        self.selectedCollectionMode = mode
    }
    
    // MARK: - Sensor Configuration Access
    
    /// 특정 센서의 샘플 수를 반환
    public func getSampleCount(for sensor: SensorType) -> Int {
        return self.sensorConfigurations[sensor]?.sampleCount ?? SensorConfiguration.defaultConfiguration(for: sensor).sampleCount
    }
    
    /// 특정 센서의 시간(초)을 반환
    public func getDuration(for sensor: SensorType) -> Int {
        return self.sensorConfigurations[sensor]?.duration ?? SensorConfiguration.defaultConfiguration(for: sensor).duration
    }
    
    /// 특정 센서의 샘플 수 텍스트를 반환
    public func getSampleCountText(for sensor: SensorType) -> String {
        return self.sensorConfigurations[sensor]?.sampleCountText ?? "\(self.getSampleCount(for: sensor))"
    }
    
    /// 특정 센서의 시간 텍스트를 반환
    public func getDurationText(for sensor: SensorType) -> String {
        return self.sensorConfigurations[sensor]?.durationText ?? "\(self.getDuration(for: sensor))"
    }
    
    /// 특정 센서의 샘플 수를 설정
    public func setSampleCount(_ value: Int, for sensor: SensorType) {
        // 기록 중이라면 경고 후 사용자 선택 요청
        if isMonitoringActive && self.bluetoothKit.isRecording {
            print("⚠️ 기록 중 샘플 수 변경 시도 감지")
            // UI에 경고 팝업 표시 요청 (설정 변경)
            self.pendingConfigurationChange = .sampleCount(value: value, sensor: sensor)
            self.showRecordingChangeWarning = true
            return
        }
        
        // 기록 중이 아니라면 즉시 적용
        self.applySampleCountChange(value, for: sensor)
    }
    
    /// 특정 센서의 시간을 설정
    public func setDuration(_ value: Int, for sensor: SensorType) {
        // 기록 중이라면 경고 후 사용자 선택 요청
        if isMonitoringActive && self.bluetoothKit.isRecording {
            print("⚠️ 기록 중 시간 설정 변경 시도 감지")
            // UI에 경고 팝업 표시 요청 (설정 변경)
            self.pendingConfigurationChange = .duration(value: value, sensor: sensor)
            self.showRecordingChangeWarning = true
            return
        }
        
        // 기록 중이 아니라면 즉시 적용
        self.applyDurationChange(value, for: sensor)
    }
    
    /// 특정 센서의 샘플 수 텍스트를 설정
    public func setSampleCountText(_ text: String, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.sampleCountText = text
    }
    
    /// 특정 센서의 시간 텍스트를 설정
    public func setDurationText(_ text: String, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.durationText = text
    }
    
    // MARK: - Validation Methods
    
    /// 샘플 수 유효성 검사
    public func validateSampleCount(_ text: String, for sensor: SensorType) -> ValidationResult {
        return self.validateValue(text, for: sensor, valueType: .sampleCount, range: ValidationRange.sampleCount)
    }
    
    /// 시간 유효성 검사
    public func validateDuration(_ text: String, for sensor: SensorType) -> ValidationResult {
        return self.validateValue(text, for: sensor, valueType: .duration, range: ValidationRange.duration)
    }
    
    // MARK: - Helper Methods
    
    public func getExpectedTime(for sensor: SensorType, sampleCount: Int) -> Double {
        return sensor.expectedTime(for: sampleCount)
    }
    
    public func getExpectedSamples(for sensor: SensorType, duration: Int) -> Int {
        return sensor.expectedSamples(for: TimeInterval(duration))
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
    
    // MARK: - Private Methods
    
    private enum ValueType {
        case sampleCount
        case duration
    }
    
    /// 기본 설정 초기화
    private func initializeDefaultConfigurations() {
        for sensorType in SensorType.allCases {
            self.sensorConfigurations[sensorType] = SensorConfiguration.defaultConfiguration(for: sensorType)
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
        case .duration:
            self.updateDuration(clampedValue, for: sensor, originalValue: value)
        }
        
        return ValidationResult(isValid: true)
    }
    
    /// 배치 델리게이트 설정
    private func setupBatchDelegate() {
        if self.batchDelegate == nil {
            self.batchDelegate = BatchDataConsoleLogger()
            self.bluetoothKit.batchDataDelegate = self.batchDelegate
        }
        
        self.batchDelegate?.updateSelectedSensors(self.selectedSensors)
        print("🔧 BatchDataConsoleLogger 설정 완료 - 선택된 센서: \(self.selectedSensors.map { $0.displayName }.joined(separator: ", "))")
    }
    
    /// 모든 센서 설정 적용
    private func configureAllSensors() {
        for sensorType in SensorType.allCases {
            if self.selectedSensors.contains(sensorType) {
                self.configureSensor(sensorType, isInitial: true)
            } else {
                self.bluetoothKit.disableDataCollection(for: sensorType)
                print("🚫 초기 비활성화: \(sensorType.displayName) - 데이터 수집 제외")
            }
        }
    }
    
    /// 변경사항 적용
    private func applyChanges() {
        print("🔄 센서 선택 변경 감지 - 설정 업데이트 중...")
        self.setupBatchDelegate()
        
        if self.bluetoothKit.isRecording {
            self.bluetoothKit.updateRecordingSensors()
        }
        
        self.configureAllSensors()
        print("✅ 센서 설정 업데이트 완료")
    }
    
    /// 특정 센서 설정
    private func configureSensor(_ sensor: SensorType, isInitial: Bool = false) {
        let prefix = isInitial ? "🔧 초기 설정" : "🔄 자동 변경"
        
        switch self.selectedCollectionMode {
        case .sampleCount:
            let sampleCount = self.getSampleCount(for: sensor)
            self.bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensor)
            
            let expectedTime = self.getExpectedTime(for: sensor, sampleCount: sampleCount)
            print("\(prefix): \(sensor.displayName) - \(sampleCount)개 샘플마다 배치 수신")
            print("   → \(sensor.displayName): \(sampleCount)개 샘플 = 약 \(String(format: "%.1f", expectedTime))초")
            
        case .duration:
            let duration = self.getDuration(for: sensor)
            self.bluetoothKit.setDataCollection(timeInterval: TimeInterval(duration), for: sensor)
            
            let expectedSamples = self.getExpectedSamples(for: sensor, duration: duration)
            print("\(prefix): \(sensor.displayName) - \(duration)초마다 배치 수신")
            print("   → \(sensor.displayName): \(duration)초마다 약 \(expectedSamples)개 샘플 예상")
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
    private func updateDuration(_ value: Int, for sensor: SensorType, originalValue: Int) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.duration = value
        if value != originalValue {
            self.sensorConfigurations[sensor]?.durationText = "\(value)"
        }
    }
    
    /// 센서 선택 변경에 따라 BluetoothKit의 데이터 수집을 재설정합니다.
    private func reconfigureSensorsForSelection() {
        // ⭐️ 중요: BluetoothKit에 변경된 센서 선택을 설정하여 BLE notify 재설정
        self.bluetoothKit.setSelectedSensors(self.selectedSensors)
        print("📡 BLE Notify 재설정: \(self.selectedSensors.map { $0.displayName }.joined(separator: ", "))")
        
        for sensorType in SensorType.allCases {
            if self.selectedSensors.contains(sensorType) {
                // 선택된 센서: 데이터 수집 재활성화
                self.configureSensor(sensorType, isInitial: false)
                print("✅ 재활성화: \(sensorType.displayName) - 데이터 수집 재개")
            } else {
                // 선택 해제된 센서: 데이터 수집 비활성화
                self.bluetoothKit.disableDataCollection(for: sensorType)
                print("🚫 비활성화: \(sensorType.displayName) - 데이터 수집 중지")
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
            print("🔄 샘플 수 변경 적용: \(sensor.displayName) - \(value)개 샘플")
        }
    }
    
    /// 시간 변경 적용
    private func applyDurationChange(_ value: Int, for sensor: SensorType) {
        self.ensureConfigurationExists(for: sensor)
        self.sensorConfigurations[sensor]?.duration = value
        self.sensorConfigurations[sensor]?.durationText = "\(value)"
        
        // 모니터링 중이라면 센서 재설정
        if isMonitoringActive && self.selectedSensors.contains(sensor) {
            self.configureSensor(sensor, isInitial: false)
            print("🔄 시간 설정 변경 적용: \(sensor.displayName) - \(value)초")
        }
    }
    
    /// 센서 설정이 존재하는지 확인하고 없으면 생성
    private func ensureConfigurationExists(for sensor: SensorType) {
        if self.sensorConfigurations[sensor] == nil {
            self.sensorConfigurations[sensor] = SensorConfiguration.defaultConfiguration(for: sensor)
        }
    }
} 