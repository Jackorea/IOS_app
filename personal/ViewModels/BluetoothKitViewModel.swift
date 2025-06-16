import SwiftUI
import BluetoothKit
import Combine

/// BluetoothKit SDK를 SwiftUI에서 사용하기 위한 래핑 ViewModel
/// 순수 비즈니스 로직인 SDK를 UI 프레임워크와 연결하는 역할
@MainActor
class BluetoothKitViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI 바인딩용)
    
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var connectionStatusDescription: String = "연결 안됨"
    @Published var isScanning: Bool = false
    @Published var isRecording: Bool = false
    @Published var isAutoReconnectEnabled: Bool = true
    @Published var latestEEGReading: EEGReading?
    @Published var latestPPGReading: PPGReading?
    @Published var latestAccelerometerReading: AccelerometerReading?
    @Published var latestBatteryReading: BatteryReading?
    @Published var recordedFiles: [URL] = []
    @Published var isBluetoothDisabled: Bool = false
    
    // MARK: - SDK Instance
    
    private let _bluetoothKit: BluetoothKit
    
    /// SDK 인스턴스에 접근하기 위한 프로퍼티 (특별한 경우에만 사용)
    var bluetoothKit: BluetoothKit {
        return _bluetoothKit
    }
    
    // MARK: - Computed Properties (SDK 위임)
    
    var isConnected: Bool {
        if case .connected(_) = _bluetoothKit.connectionState {
            return true
        }
        return false
    }
    
    var recordingsDirectory: URL {
        _bluetoothKit.recordingsDirectory
    }
    
    // MARK: - Initialization
    
    init() {
        self._bluetoothKit = BluetoothKit()
        self._bluetoothKit.delegate = self
        
        // 현재 상태를 UI에 동기화
        syncFromSDK()
    }
    
    // MARK: - Public Methods (SDK 위임)
    
    func startScanning() {
        _bluetoothKit.startScanning()
    }
    
    func stopScanning() {
        _bluetoothKit.stopScanning()
    }
    
    func connect(to device: BluetoothDevice) {
        _bluetoothKit.connect(to: device)
    }
    
    func disconnect() {
        _bluetoothKit.disconnect()
    }
    
    func startRecording() {
        _bluetoothKit.startRecording()
    }
    
    func stopRecording() {
        _bluetoothKit.stopRecording()
    }
    
    func setAutoReconnect(enabled: Bool) {
        _bluetoothKit.setAutoReconnect(enabled: enabled)
    }
    
    // MARK: - Batch Data Methods
    
    var batchDataDelegate: SensorBatchDataDelegate? {
        get { _bluetoothKit.batchDataDelegate }
        set { _bluetoothKit.batchDataDelegate = newValue }
    }
    
    func setDataCollection(timeInterval: TimeInterval, for sensorType: SensorType) {
        _bluetoothKit.setDataCollection(timeInterval: timeInterval, for: sensorType)
    }
    
    func setDataCollection(sampleCount: Int, for sensorType: SensorType) {
        _bluetoothKit.setDataCollection(sampleCount: sampleCount, for: sensorType)
    }
    
    func disableDataCollection(for sensorType: SensorType) {
        _bluetoothKit.disableDataCollection(for: sensorType)
    }
    
    func disableAllDataCollection() {
        _bluetoothKit.disableAllDataCollection()
    }
    
    func updateRecordingSensors() {
        _bluetoothKit.updateRecordingSensors()
    }
    
    // MARK: - File Management
    
    func refreshRecordedFiles() {
        recordedFiles = _bluetoothKit.recordedFiles
    }
    
    func deleteFile(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
        refreshRecordedFiles()
    }
    
    func deleteAllFiles() throws {
        for fileURL in recordedFiles {
            try FileManager.default.removeItem(at: fileURL)
        }
        refreshRecordedFiles()
    }
    
    // MARK: - Private Methods
    
    /// SDK의 현재 상태를 UI에 동기화
    private func syncFromSDK() {
        discoveredDevices = _bluetoothKit.discoveredDevices
        connectionStatusDescription = _bluetoothKit.connectionStatusDescription
        isScanning = _bluetoothKit.isScanning
        isRecording = _bluetoothKit.isRecording
        isAutoReconnectEnabled = _bluetoothKit.isAutoReconnectEnabled
        latestEEGReading = _bluetoothKit.latestEEGReading
        latestPPGReading = _bluetoothKit.latestPPGReading
        latestAccelerometerReading = _bluetoothKit.latestAccelerometerReading
        latestBatteryReading = _bluetoothKit.latestBatteryReading
        recordedFiles = _bluetoothKit.recordedFiles
        isBluetoothDisabled = _bluetoothKit.isBluetoothDisabled
    }
}

// MARK: - BluetoothKitDelegate

extension BluetoothKitViewModel: BluetoothKitDelegate {
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateDevices devices: [BluetoothDevice]) {
        discoveredDevices = devices
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateConnectionStatus status: String) {
        connectionStatusDescription = status
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateScanningState isScanning: Bool) {
        self.isScanning = isScanning
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateRecordingState isRecording: Bool) {
        self.isRecording = isRecording
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAutoReconnectState isEnabled: Bool) {
        self.isAutoReconnectEnabled = isEnabled
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didReceiveEEGData reading: EEGReading) {
        latestEEGReading = reading
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didReceivePPGData reading: PPGReading) {
        latestPPGReading = reading
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didReceiveAccelerometerData reading: AccelerometerReading) {
        latestAccelerometerReading = reading
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didReceiveBatteryData reading: BatteryReading) {
        latestBatteryReading = reading
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateRecordedFiles files: [URL]) {
        recordedFiles = files
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBluetoothState isDisabled: Bool) {
        self.isBluetoothDisabled = isDisabled
    }
} 