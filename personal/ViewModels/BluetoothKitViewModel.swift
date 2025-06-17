import SwiftUI
import BluetoothKit
import Combine

/// BluetoothKit SDK를 SwiftUI에서 사용할 수 있도록 래핑하는 ViewModel
/// 기존 UI/UX를 그대로 유지하면서 순수 비즈니스 로직과 UI를 분리합니다.
@MainActor
class BluetoothKitViewModel: ObservableObject, BluetoothKitDelegate {
    
    // MARK: - Published Properties (UI 바인딩용)
    
    /// 스캔 중 발견된 Bluetooth 디바이스 목록
    @Published public var discoveredDevices: [BluetoothDevice] = []
    
    /// 현재 연결 상태의 사용자 친화적인 설명
    @Published public var connectionStatusDescription: String = "연결 안됨"
    
    /// 라이브러리가 현재 디바이스를 스캔 중인지 여부
    @Published public var isScanning: Bool = false
    
    /// 데이터 기록이 현재 활성화되어 있는지 여부
    @Published public var isRecording: Bool = false
    
    /// auto-reconnection이 현재 활성화되어 있는지 여부
    @Published public var isAutoReconnectEnabled: Bool = true
    
    /// 가장 최근의 EEG (뇌전도) 읽기값
    @Published public var latestEEGReading: EEGReading?
    
    /// 가장 최근의 PPG (광전 용적 맥파) 읽기값
    @Published public var latestPPGReading: PPGReading?
    
    /// 가장 최근의 가속도계 읽기값
    @Published public var latestAccelerometerReading: AccelerometerReading?
    
    /// 가장 최근의 배터리 레벨 읽기값
    @Published public var latestBatteryReading: BatteryReading?
    
    /// 기록된 파일 목록
    @Published public var recordedFiles: [URL] = []
    
    /// Bluetooth가 비활성화되어 있는지 여부
    @Published public var isBluetoothDisabled: Bool = false
    
    /// 현재 연결 상태
    @Published public var connectionState: ConnectionState = .disconnected
    
    /// 가속도계 모드 (원시값 vs 움직임)
    @Published public var accelerometerMode: AccelerometerMode = .raw
    
    // MARK: - SDK Instance
    
    /// 실제 비즈니스 로직을 담당하는 BluetoothKit 인스턴스
    private let bluetoothKit: BluetoothKit
    
    /// SDK 인스턴스에 접근할 수 있는 프로퍼티 (다른 ViewModel에서 사용)
    public var sdkInstance: BluetoothKit {
        return bluetoothKit
    }
    
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
        bluetoothKit.startScanning()
    }
    
    /// Bluetooth 디바이스 스캔을 중지합니다.
    public func stopScanning() {
        bluetoothKit.stopScanning()
    }
    
    /// 특정 Bluetooth 디바이스에 연결합니다.
    public func connect(to device: BluetoothDevice) {
        bluetoothKit.connect(to: device)
    }
    
    /// 현재 연결된 디바이스에서 연결을 해제합니다.
    public func disconnect() {
        bluetoothKit.disconnect()
    }
    
    /// 센서 데이터를 파일로 기록하기 시작합니다.
    public func startRecording() {
        bluetoothKit.startRecording()
    }
    
    /// 센서 데이터 기록을 중지합니다.
    public func stopRecording() {
        bluetoothKit.stopRecording()
    }
    
    /// 기록이 저장되는 디렉토리를 가져옵니다.
    public var recordingsDirectory: URL {
        return bluetoothKit.recordingsDirectory
    }
    
    /// 현재 디바이스에 연결되어 있는지 확인합니다.
    public var isConnected: Bool {
        return bluetoothKit.isConnected
    }
    
    /// 배치 단위로 센서 데이터를 수신하는 델리게이트
    public weak var batchDataDelegate: SensorBatchDataDelegate? {
        get { bluetoothKit.batchDataDelegate }
        set { bluetoothKit.batchDataDelegate = newValue }
    }
    
    /// 자동 재연결 기능을 설정합니다.
    public func setAutoReconnect(enabled: Bool) {
        bluetoothKit.setAutoReconnect(enabled: enabled)
    }
    
    // MARK: - Batch Data Collection Methods
    
    /// 시간 간격을 기준으로 배치 데이터 수집을 설정합니다.
    public func setDataCollection(timeInterval: TimeInterval, for sensorType: SensorType) {
        bluetoothKit.setDataCollection(timeInterval: timeInterval, for: sensorType)
    }
    
    /// 샘플 개수를 기준으로 배치 데이터 수집을 설정합니다.
    public func setDataCollection(sampleCount: Int, for sensorType: SensorType) {
        bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensorType)
    }
    
    /// 특정 센서의 배치 데이터 수집을 비활성화합니다.
    public func disableDataCollection(for sensorType: SensorType) {
        bluetoothKit.disableDataCollection(for: sensorType)
    }
    
    /// 모든 센서의 배치 데이터 수집을 비활성화합니다.
    public func disableAllDataCollection() {
        bluetoothKit.disableAllDataCollection()
    }
    
    /// 기록 중에 선택된 센서를 업데이트합니다.
    public func updateRecordingSensors() {
        bluetoothKit.updateRecordingSensors()
    }
    
    // MARK: - Private Methods
    
    /// SDK의 초기 상태를 ViewModel에 동기화합니다.
    private func syncInitialState() {
        // 초기값들을 SDK에서 가져와서 설정
        discoveredDevices = bluetoothKit.discoveredDevices
        connectionStatusDescription = bluetoothKit.connectionStatusDescription
        isScanning = bluetoothKit.isScanning
        isRecording = bluetoothKit.isRecording
        isAutoReconnectEnabled = bluetoothKit.isAutoReconnectEnabled
        latestEEGReading = bluetoothKit.latestEEGReading
        latestPPGReading = bluetoothKit.latestPPGReading
        latestAccelerometerReading = bluetoothKit.latestAccelerometerReading
        latestBatteryReading = bluetoothKit.latestBatteryReading
        recordedFiles = bluetoothKit.recordedFiles
        isBluetoothDisabled = bluetoothKit.isBluetoothDisabled
        connectionState = bluetoothKit.connectionState
        accelerometerMode = bluetoothKit.accelerometerMode
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
        discoveredDevices = devices
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
        latestEEGReading = reading
    }
    
    /// PPG 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdatePPGReading reading: PPGReading?) {
        latestPPGReading = reading
    }
    
    /// 가속도계 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAccelerometerReading reading: AccelerometerReading?) {
        latestAccelerometerReading = reading
    }
    
    /// 배터리 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBatteryReading reading: BatteryReading?) {
        latestBatteryReading = reading
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
        connectionState = state
    }
    
    /// 가속도계 모드가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAccelerometerMode mode: AccelerometerMode) {
        accelerometerMode = mode
    }
} 