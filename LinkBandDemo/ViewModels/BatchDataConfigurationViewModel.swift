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
    
    /// 배치 데이터 모니터링을 시작합니다.
    /// - Note: UI 반응성을 위해 isMonitoringActive 상태를 즉시 업데이트합니다.
    public func startMonitoring() {
        bluetoothKit.startBatchMonitoring()
        // 즉시 상태 업데이트 (UI 반응성 향상)
        isMonitoringActive = true
    }
    
    /// 배치 데이터 모니터링을 중지합니다.
    /// - Note: UI 반응성을 위해 isMonitoringActive 상태를 즉시 업데이트합니다.
    public func stopMonitoring() {
        bluetoothKit.stopBatchMonitoring()
        // 즉시 상태 업데이트 (UI 반응성 향상)
        isMonitoringActive = false
    }
    
    /// 배치 모니터링할 센서 선택을 업데이트합니다.
    /// - Parameter sensors: 선택할 센서들의 집합
    /// - Note: SensorKind를 SensorType으로 변환하여 SDK에 전달하고, UI 동기화를 위해 로컬 상태도 업데이트합니다.
    public func updateSensorSelection(_ sensors: Set<SensorKind>) {
        let sdkSensors = Set(sensors.map { $0.sdkType })
        bluetoothKit.updateBatchSensorSelection(sdkSensors)
        // UI 동기화를 위해 로컬 상태도 업데이트
        selectedSensors = sensors
    }
    
    /// 배치 데이터 수집 모드를 업데이트합니다.
    /// - Parameter mode: 설정할 수집 모드 (샘플 수, 시간(초), 시간(분))
    public func updateCollectionMode(_ mode: CollectionModeKind) {
        bluetoothKit.updateBatchCollectionMode(mode.sdkMode)
    }
    
    /// 사용자가 경고 팝업에서 "기록 중지 후 변경"을 선택했을 때 호출됩니다.
    /// - Note: 기록 중에 센서 선택을 변경하려 할 때 표시되는 경고 팝업의 확인 동작입니다.
    public func confirmSensorChangeWithRecordingStop() {
        bluetoothKit.confirmBatchSensorChangeWithRecordingStop()
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출됩니다.
    /// - Note: 기록 중에 센서 선택 변경을 취소하는 동작입니다.
    public func cancelSensorChange() {
        bluetoothKit.cancelBatchSensorChange()
    }
    
    // MARK: - Sensor Configuration Access - SensorKind 어댑터 메서드들
    
    /// 특정 센서의 현재 샘플 수 설정값을 반환합니다.
    /// - Parameter sensor: 조회할 센서 타입
    /// - Returns: 설정된 샘플 수
    public func getSampleCount(for sensor: SensorKind) -> Int {
        return bluetoothKit.getBatchSampleCount(for: sensor.sdkType)
    }
    
    /// 특정 센서의 현재 시간(초) 설정값을 반환합니다.
    /// - Parameter sensor: 조회할 센서 타입
    /// - Returns: 설정된 시간(초)
    public func getSeconds(for sensor: SensorKind) -> Int {
        return bluetoothKit.getBatchSeconds(for: sensor.sdkType)
    }
    
    /// 특정 센서의 샘플 수 텍스트 필드 값을 반환합니다.
    /// - Parameter sensor: 조회할 센서 타입
    /// - Returns: UI에서 표시되는 샘플 수 텍스트
    public func getSampleCountText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchSampleCountText(for: sensor.sdkType)
    }
    
    /// 특정 센서의 시간(초) 텍스트 필드 값을 반환합니다.
    /// - Parameter sensor: 조회할 센서 타입
    /// - Returns: UI에서 표시되는 시간(초) 텍스트
    public func getSecondsText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchSecondsText(for: sensor.sdkType)
    }
    
    /// 특정 센서의 현재 분 설정값을 반환합니다.
    /// - Parameter sensor: 조회할 센서 타입
    /// - Returns: 설정된 시간(분)
    public func getMinutes(for sensor: SensorKind) -> Int {
        return bluetoothKit.getBatchMinutes(for: sensor.sdkType)
    }
    
    /// 특정 센서의 분 텍스트 필드 값을 반환합니다.
    /// - Parameter sensor: 조회할 센서 타입
    /// - Returns: UI에서 표시되는 시간(분) 텍스트
    public func getMinutesText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchMinutesText(for: sensor.sdkType)
    }
    
    /// 특정 센서의 샘플 수를 설정합니다.
    /// - Parameters:
    ///   - value: 설정할 샘플 수
    ///   - sensor: 대상 센서 타입
    public func setSampleCount(_ value: Int, for sensor: SensorKind) {
        bluetoothKit.setBatchSampleCount(value, for: sensor.sdkType)
    }
    
    /// 특정 센서의 시간(초)을 설정합니다.
    /// - Parameters:
    ///   - value: 설정할 시간(초)
    ///   - sensor: 대상 센서 타입
    public func setSeconds(_ value: Int, for sensor: SensorKind) {
        bluetoothKit.setBatchSeconds(value, for: sensor.sdkType)
    }
    
    /// 특정 센서의 시간(분)을 설정합니다.
    /// - Parameters:
    ///   - value: 설정할 시간(분)
    ///   - sensor: 대상 센서 타입
    public func setMinutes(_ value: Int, for sensor: SensorKind) {
        bluetoothKit.setBatchMinutes(value, for: sensor.sdkType)
    }
    
    /// 특정 센서의 샘플 수 텍스트 필드 값을 설정합니다.
    /// - Parameters:
    ///   - text: 설정할 텍스트 값
    ///   - sensor: 대상 센서 타입
    public func setSampleCountText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchSampleCountText(text, for: sensor.sdkType)
    }
    
    /// 특정 센서의 시간(초) 텍스트 필드 값을 설정합니다.
    /// - Parameters:
    ///   - text: 설정할 텍스트 값
    ///   - sensor: 대상 센서 타입
    public func setSecondsText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchSecondsText(text, for: sensor.sdkType)
    }
    
    /// 특정 센서의 시간(분) 텍스트 필드 값을 설정합니다.
    /// - Parameters:
    ///   - text: 설정할 텍스트 값
    ///   - sensor: 대상 센서 타입
    public func setMinutesText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchMinutesText(text, for: sensor.sdkType)
    }
    
    // MARK: - Validation Methods - SensorKind 어댑터 메서드들
    
    /// 특정 센서의 샘플 수 텍스트를 검증하고 UI 상태를 업데이트합니다.
    /// - Parameters:
    ///   - text: 검증할 텍스트 값
    ///   - sensor: 대상 센서 타입
    /// - Returns: 검증 통과 여부
    /// - Note: 검증 실패 시 showValidationError와 validationMessage를 자동으로 업데이트합니다.
    public func validateSampleCount(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchSampleCount(text, for: sensor.sdkType)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    /// 특정 센서의 시간(초) 텍스트를 검증하고 UI 상태를 업데이트합니다.
    /// - Parameters:
    ///   - text: 검증할 텍스트 값
    ///   - sensor: 대상 센서 타입
    /// - Returns: 검증 통과 여부
    /// - Note: 검증 실패 시 showValidationError와 validationMessage를 자동으로 업데이트합니다.
    public func validateSeconds(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchSeconds(text, for: sensor.sdkType)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    /// 특정 센서의 시간(분) 텍스트를 검증하고 UI 상태를 업데이트합니다.
    /// - Parameters:
    ///   - text: 검증할 텍스트 값
    ///   - sensor: 대상 센서 타입
    /// - Returns: 검증 통과 여부
    /// - Note: 검증 실패 시 showValidationError와 validationMessage를 자동으로 업데이트합니다.
    public func validateMinutes(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchMinutes(text, for: sensor.sdkType)
        
        showValidationError = !result.isValid
        validationMessage = result.message ?? ""
        
        return result.isValid
    }
    
    // MARK: - Helper Methods - SensorKind 어댑터 메서드들
    
    /// 특정 센서와 샘플 수를 기준으로 예상 수집 시간을 계산합니다.
    /// - Parameters:
    ///   - sensor: 대상 센서 타입
    ///   - sampleCount: 샘플 수
    /// - Returns: 예상 수집 시간(초)
    public func getExpectedTime(for sensor: SensorKind, sampleCount: Int) -> Double {
        return bluetoothKit.getBatchExpectedTime(for: sensor.sdkType, sampleCount: sampleCount)
    }
    
    /// 특정 센서와 시간(초)을 기준으로 예상 샘플 수를 계산합니다.
    /// - Parameters:
    ///   - sensor: 대상 센서 타입
    ///   - seconds: 시간(초)
    /// - Returns: 예상 샘플 수
    public func getExpectedSamples(for sensor: SensorKind, seconds: Int) -> Int {
        return bluetoothKit.getBatchExpectedSamples(for: sensor.sdkType, seconds: seconds)
    }
    
    /// 특정 센서와 시간(분)을 기준으로 예상 샘플 수를 계산합니다.
    /// - Parameters:
    ///   - sensor: 대상 센서 타입
    ///   - minutes: 시간(분)
    /// - Returns: 예상 샘플 수
    public func getExpectedSamplesForMinutes(for sensor: SensorKind, minutes: Int) -> Int {
        return bluetoothKit.getBatchExpectedSamplesForMinutes(for: sensor.sdkType, minutes: minutes)
    }
    
    /// 특정 센서와 샘플 수를 기준으로 예상 수집 시간(분)을 계산합니다.
    /// - Parameters:
    ///   - sensor: 대상 센서 타입
    ///   - sampleCount: 샘플 수
    /// - Returns: 예상 수집 시간(분)
    public func getExpectedMinutes(for sensor: SensorKind, sampleCount: Int) -> Double {
        return bluetoothKit.getBatchExpectedMinutes(for: sensor.sdkType, sampleCount: sampleCount)
    }
    
    /// 모든 센서의 배치 설정을 기본값으로 재설정합니다.
    public func resetToDefaults() {
        bluetoothKit.resetBatchToDefaults()
    }
    
    /// 현재 배치 설정의 요약 정보를 문자열로 반환합니다.
    /// - Returns: 설정 요약 문자열
    public func getConfigurationSummary() -> String {
        return bluetoothKit.getBatchConfigurationSummary()
    }
    
    /// 특정 센서가 현재 선택되어 있는지 확인합니다.
    /// - Parameter sensor: 확인할 센서 타입
    /// - Returns: 센서 선택 여부
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