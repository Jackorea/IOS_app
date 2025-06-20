import SwiftUI
import BluetoothKit
import Combine

// MARK: - SDK 변환 확장 (internal 사용)
internal extension EEGData {
    init(from reading: EEGReading) {
        self.init(
            channel1: reading.channel1,
            channel2: reading.channel2,
            ch1Raw: Int(reading.ch1Raw),
            ch2Raw: Int(reading.ch2Raw),
            leadOff: reading.leadOff,
            timestamp: reading.timestamp
        )
    }
}

internal extension PPGData {
    init(from reading: PPGReading) {
        self.init(
            red: Int(reading.red),
            ir: Int(reading.ir),
            timestamp: reading.timestamp
        )
    }
}

internal extension AccelerometerData {
    init(from reading: AccelerometerReading) {
        self.init(
            x: Int(reading.x),
            y: Int(reading.y),
            z: Int(reading.z),
            timestamp: reading.timestamp
        )
    }
}

internal extension BatteryData {
    init(from reading: BatteryReading) {
        self.init(
            level: Int(reading.level),
            timestamp: reading.timestamp
        )
    }
}

internal extension DeviceInfo {
    init(from device: BluetoothDevice) {
        // peripheral.identifier에 접근할 수 없으므로 name을 UUID로 사용
        // 실제로는 BluetoothKit에서 proper UUID를 제공해야 함
        self.init(
            id: UUID(), // 임시 UUID 생성 - SDK에서 proper identifier 제공 필요
            name: device.name
        )
    }
}

internal extension SensorKind {
    var sdkType: SensorType {
        switch self {
        case .eeg: return .eeg
        case .ppg: return .ppg
        case .accelerometer: return .accelerometer
        case .battery: return .battery
        }
    }
    
    static func from(_ sdkType: SensorType) -> SensorKind {
        switch sdkType {
        case .eeg: return .eeg
        case .ppg: return .ppg
        case .accelerometer: return .accelerometer
        case .battery: return .battery
        }
    }
}

internal extension DeviceConnectionState {
    var sdkState: ConnectionState {
        switch self {
        case .disconnected: return .disconnected
        case .scanning: return .scanning
        case .connecting: return .connecting("Unknown Device")
        case .connected: return .connected("Unknown Device")
        case .reconnecting: return .reconnecting("Unknown Device")
        case .failed: return .failed(NSError(domain: "AdapterError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
        }
    }
    
    static func from(_ sdkState: ConnectionState) -> DeviceConnectionState {
        switch sdkState {
        case .disconnected: return .disconnected
        case .scanning: return .scanning
        case .connecting(_): return .connecting
        case .connected(_): return .connected
        case .reconnecting(_): return .reconnecting
        case .failed(_): return .failed
        }
    }
}

internal extension AccelMode {
    var sdkMode: AccelerometerMode {
        switch self {
        case .raw: return .raw
        case .motion: return .motion
        }
    }
    
    static func from(_ sdkMode: AccelerometerMode) -> AccelMode {
        switch sdkMode {
        case .raw: return .raw
        case .motion: return .motion
        }
    }
}

internal extension CollectionModeKind {
    var sdkMode: BatchDataConfigurationManager.CollectionMode {
        switch self {
        case .sampleCount: return .sampleCount
        case .seconds: return .seconds
        case .minutes: return .minutes
        }
    }
    
    static func from(_ sdkMode: BatchDataConfigurationManager.CollectionMode) -> CollectionModeKind {
        switch sdkMode {
        case .sampleCount: return .sampleCount
        case .seconds: return .seconds
        case .minutes: return .minutes
        }
    }
}

/// BluetoothKit SDK를 SwiftUI에서 사용할 수 있도록 래핑하는 ViewModel
/// 기존 UI/UX를 그대로 유지하면서 순수 비즈니스 로직과 UI를 분리합니다.
@MainActor
class BluetoothKitViewModel: ObservableObject, BluetoothKitDelegate {
    
    // MARK: - Published Properties (UI 바인딩용)
    
    /// 스캔 중 발견된 Bluetooth 디바이스 목록
    @Published public var discoveredDevices: [DeviceInfo] = []
    
    /// 현재 연결 상태의 사용자 친화적인 설명
    @Published public var connectionStatusDescription: String = "연결 안됨"
    
    /// 라이브러리가 현재 디바이스를 스캔 중인지 여부
    @Published public var isScanning: Bool = false
    
    /// 데이터 기록이 현재 활성화되어 있는지 여부
    @Published public var isRecording: Bool = false
    
    /// auto-reconnection이 현재 활성화되어 있는지 여부
    @Published public var isAutoReconnectEnabled: Bool = true
    
    /// 가장 최근의 EEG (뇌전도) 읽기값
    @Published public var latestEEGReading: EEGData?
    
    /// 가장 최근의 PPG (광전 용적 맥파) 읽기값
    @Published public var latestPPGReading: PPGData?
    
    /// 가장 최근의 가속도계 읽기값
    @Published public var latestAccelerometerReading: AccelerometerData?
    
    /// 가장 최근의 배터리 레벨 읽기값
    @Published public var latestBatteryReading: BatteryData?
    
    /// 기록된 파일 목록
    @Published public var recordedFiles: [URL] = []
    
    /// Bluetooth가 비활성화되어 있는지 여부
    @Published public var isBluetoothDisabled: Bool = false
    
    /// 현재 연결 상태
    @Published public var connectionState: DeviceConnectionState = .disconnected
    
    /// 가속도계 모드 (원시값 vs 움직임)
    @Published public var accelerometerMode: AccelMode = .raw {
        didSet {
            // 값이 실제로 변경되었을 때만 SDK 인스턴스 업데이트
            guard oldValue != accelerometerMode else { return }
            bluetoothKit.accelerometerMode = accelerometerMode.sdkMode
        }
    }
    
    // MARK: - SDK Instance
    
    /// 실제 비즈니스 로직을 담당하는 BluetoothKit 인스턴스
    private let bluetoothKit: BluetoothKit
    
    // MARK: - Initialization
    
    /// 새로운 BluetoothKitViewModel 인스턴스를 생성합니다.
    public init() {
        self.bluetoothKit = BluetoothKit()
        
        // 델리게이트 설정
        bluetoothKit.delegate = self
        
        // 초기 상태 동기화
        syncInitialState()
    }
    
    // MARK: - Public Interface (SDK 메서드들을 래핑)
    
    /// Bluetooth 디바이스 스캔을 시작합니다.
    public func startScanning() {
        try? bluetoothKit.startScanning()
    }
    
    /// Bluetooth 디바이스 스캔을 중지합니다.
    public func stopScanning() {
        try? bluetoothKit.stopScanning()
    }
    
    /// 특정 Bluetooth 디바이스에 연결합니다.
    public func connect(to device: DeviceInfo) {
        // DeviceInfo를 BluetoothDevice로 변환해서 연결
        if let sdkDevice = bluetoothKit.discoveredDevices.first(where: { $0.name == device.name }) {
            try? bluetoothKit.connect(to: sdkDevice)
        }
    }
    
    /// 현재 연결된 디바이스에서 연결을 해제합니다.
    public func disconnect() {
        try? bluetoothKit.disconnect()
    }
    
    /// 센서 데이터를 파일로 기록하기 시작합니다.
    public func startRecording() {
        try? bluetoothKit.startRecording()
    }
    
    /// 센서 데이터 기록을 중지합니다.
    public func stopRecording() {
        try? bluetoothKit.stopRecording()
    }
    
    /// 기록이 저장되는 디렉토리를 가져옵니다.
    public var recordingsDirectory: URL {
        return bluetoothKit.recordingsDirectory
    }
    
    /// 현재 디바이스에 연결되어 있는지 확인합니다.
    public var isConnected: Bool {
        return bluetoothKit.isConnected
    }
    
    /// 자동 재연결 기능을 설정합니다.
    public func setAutoReconnect(enabled: Bool) {
        try? bluetoothKit.setAutoReconnect(enabled: enabled)
    }
    
    // MARK: - Batch Data Collection Methods
    
    /// 시간 간격을 기준으로 배치 데이터 수집을 설정합니다.
    public func setDataCollection(timeInterval: TimeInterval, for sensorType: SensorKind) {
        try? bluetoothKit.setDataCollection(timeInterval: timeInterval, for: sensorType.sdkType)
    }
    
    /// 샘플 개수를 기준으로 배치 데이터 수집을 설정합니다.
    public func setDataCollection(sampleCount: Int, for sensorType: SensorKind) {
        try? bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensorType.sdkType)
    }
    
    /// 특정 센서의 배치 데이터 수집을 비활성화합니다.
    public func disableDataCollection(for sensorType: SensorKind) {
        try? bluetoothKit.disableDataCollection(for: sensorType.sdkType)
    }
    
    /// 모든 센서의 배치 데이터 수집을 비활성화합니다.
    public func disableAllDataCollection() {
        try? bluetoothKit.disableAllDataCollection()
    }
    
    /// 기록 중에 선택된 센서를 업데이트합니다.
    public func updateRecordingSensors(_ selectedSensors: Set<SensorKind>) {
        let sdkSensors = Set(selectedSensors.map { $0.sdkType })
        try? bluetoothKit.updateRecordingSensors(sdkSensors)
    }
    
    // MARK: - Sensor Monitoring Control
    
    /// 센서 모니터링을 활성화합니다.
    public func enableMonitoring() {
        try? bluetoothKit.enableMonitoring()
    }
    
    /// 센서 모니터링을 비활성화합니다.
    public func disableMonitoring() {
        try? bluetoothKit.disableMonitoring()
    }
    
    /// 모니터링할 센서 타입을 설정합니다.
    public func setSelectedSensors(_ sensors: Set<SensorKind>) {
        let sdkSensors = Set(sensors.map { $0.sdkType })
        try? bluetoothKit.setSelectedSensors(sdkSensors)
    }
    
    /// 현재 모니터링 중인 센서 타입들을 반환합니다.
    public var selectedSensorTypes: Set<SensorKind> {
        return Set(bluetoothKit.selectedSensorTypes.map { SensorKind.from($0) })
    }
    
    // MARK: - BatchDataConfigurationViewModel 지원 메서드들
    
    /// BatchDataConfigurationViewModel을 생성합니다 (SDK 인스턴스 직접 노출 없이)
    public func createBatchDataConfigurationViewModel() -> BatchDataConfigurationViewModel {
        return BatchDataConfigurationViewModel(bluetoothKit: bluetoothKit)
    }
    
    // MARK: - SensorKind 어댑터 메서드들 (BatchDataConfigurationViewModel 지원)
    
    /// SensorKind를 위한 샘플 수 텍스트 가져오기
    public func getSampleCountText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchSampleCountText(for: sensor.sdkType)
    }
    
    /// SensorKind를 위한 샘플 수 텍스트 설정
    public func setSampleCountText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchSampleCountText(text, for: sensor.sdkType)
    }
    
    /// SensorKind를 위한 초 단위 텍스트 가져오기
    public func getSecondsText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchSecondsText(for: sensor.sdkType)
    }
    
    /// SensorKind를 위한 초 단위 텍스트 설정
    public func setSecondsText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchSecondsText(text, for: sensor.sdkType)
    }
    
    /// SensorKind를 위한 분 단위 텍스트 가져오기
    public func getMinutesText(for sensor: SensorKind) -> String {
        return bluetoothKit.getBatchMinutesText(for: sensor.sdkType)
    }
    
    /// SensorKind를 위한 분 단위 텍스트 설정
    public func setMinutesText(_ text: String, for sensor: SensorKind) {
        bluetoothKit.setBatchMinutesText(text, for: sensor.sdkType)
    }
    
    /// SensorKind를 위한 샘플 수 검증
    public func validateSampleCount(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchSampleCount(text, for: sensor.sdkType)
        return result.isValid
    }
    
    /// SensorKind를 위한 초 단위 검증
    public func validateSeconds(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchSeconds(text, for: sensor.sdkType)
        return result.isValid
    }
    
    /// SensorKind를 위한 분 단위 검증
    public func validateMinutes(_ text: String, for sensor: SensorKind) -> Bool {
        let result = bluetoothKit.validateBatchMinutes(text, for: sensor.sdkType)
        return result.isValid
    }
    
    // MARK: - Private Methods
    
    /// SDK의 초기 상태를 ViewModel에 동기화합니다.
    private func syncInitialState() {
        // 초기값들을 SDK에서 가져와서 설정
        discoveredDevices = bluetoothKit.discoveredDevices.map { DeviceInfo(from: $0) }
        connectionStatusDescription = bluetoothKit.connectionStatusDescription
        isScanning = bluetoothKit.isScanning
        isRecording = bluetoothKit.isRecording
        isAutoReconnectEnabled = bluetoothKit.isAutoReconnectEnabled
        latestEEGReading = bluetoothKit.latestEEGReading.map { EEGData(from: $0) }
        latestPPGReading = bluetoothKit.latestPPGReading.map { PPGData(from: $0) }
        latestAccelerometerReading = bluetoothKit.latestAccelerometerReading.map { AccelerometerData(from: $0) }
        latestBatteryReading = bluetoothKit.latestBatteryReading.map { BatteryData(from: $0) }
        recordedFiles = bluetoothKit.recordedFiles
        isBluetoothDisabled = bluetoothKit.isBluetoothDisabled
        connectionState = DeviceConnectionState.from(bluetoothKit.connectionState)
        accelerometerMode = AccelMode.from(bluetoothKit.accelerometerMode)
    }
}

// MARK: - BluetoothKitDelegate Implementation

extension BluetoothKitViewModel {
    
    /// 디바이스가 발견되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didDiscoverDevice device: BluetoothDevice) {
        // 개별 디바이스 발견은 didUpdateDevices에서 처리됨
    }
    
    /// 디바이스 목록이 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateDevices devices: [BluetoothDevice]) {
        discoveredDevices = devices.map { DeviceInfo(from: $0) }
    }
    
    /// 연결 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateConnectionStatus status: String) {
        connectionStatusDescription = status
    }
    
    /// 스캔 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateScanningState isScanning: Bool) {
        self.isScanning = isScanning
    }
    
    /// 기록 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateRecordingState isRecording: Bool) {
        self.isRecording = isRecording
    }
    
    /// 자동 재연결 설정이 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAutoReconnectState isEnabled: Bool) {
        self.isAutoReconnectEnabled = isEnabled
    }
    
    /// EEG 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateEEGReading reading: EEGReading?) {
        latestEEGReading = reading.map { EEGData(from: $0) }
    }
    
    /// PPG 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdatePPGReading reading: PPGReading?) {
        latestPPGReading = reading.map { PPGData(from: $0) }
    }
    
    /// 가속도계 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAccelerometerReading reading: AccelerometerReading?) {
        latestAccelerometerReading = reading.map { AccelerometerData(from: $0) }
    }
    
    /// 배터리 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBatteryReading reading: BatteryReading?) {
        latestBatteryReading = reading.map { BatteryData(from: $0) }
    }
    
    /// 기록된 파일 목록이 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateRecordedFiles files: [URL]) {
        recordedFiles = files
    }
    
    /// Bluetooth 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBluetoothDisabled isDisabled: Bool) {
        isBluetoothDisabled = isDisabled
    }
    
    /// 연결 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateConnectionState state: ConnectionState) {
        connectionState = DeviceConnectionState.from(state)
    }
    
    /// 가속도계 모드가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAccelerometerMode mode: AccelerometerMode) {
        // 값이 실제로 다를 때만 업데이트 (무한 루프 방지)
        let newMode = AccelMode.from(mode)
        guard accelerometerMode != newMode else { return }
        accelerometerMode = newMode
    }
    
    /// 배치 모니터링 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBatchMonitoringState isActive: Bool) {
        // BatchDataConfigurationViewModel이 있다면 상태 업데이트
        // 이는 런타임에 동적으로 처리됨
    }
} 