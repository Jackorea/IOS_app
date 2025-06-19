import Foundation
import CoreBluetooth

// MARK: - BluetoothKit Delegate Protocol

/// BluetoothKit의 상태 변화를 알리는 델리게이트 프로토콜
public protocol BluetoothKitDelegate: AnyObject {
    /// 디바이스가 발견되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didDiscoverDevice device: BluetoothDevice)
    /// 디바이스 목록이 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateDevices devices: [BluetoothDevice])
    /// 연결 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateConnectionStatus status: String)
    /// 스캔 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateScanningState isScanning: Bool)
    /// 기록 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateRecordingState isRecording: Bool)
    /// 자동 재연결 설정이 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAutoReconnectState isEnabled: Bool)
    /// 배치 모니터링 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBatchMonitoringState isActive: Bool)
    /// 센서 데이터가 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateEEGReading reading: EEGReading?)
    func bluetoothKit(_ kit: BluetoothKit, didUpdatePPGReading reading: PPGReading?)
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAccelerometerReading reading: AccelerometerReading?)
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBatteryReading reading: BatteryReading?)
    /// 기록된 파일 목록이 업데이트되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateRecordedFiles files: [URL])
    /// Bluetooth 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateBluetoothDisabled isDisabled: Bool)
    /// 연결 상태가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateConnectionState state: ConnectionState)
    /// 가속도계 모드가 변경되었을 때 호출
    func bluetoothKit(_ kit: BluetoothKit, didUpdateAccelerometerMode mode: AccelerometerMode)
}

// MARK: - BluetoothKit Main Interface

/// LinkBand 센서에서 데이터를 읽고 연결을 관리하는 메인 클래스입니다.
///
/// 이 클래스는 Bluetooth Low Energy를 통해 LinkBand 디바이스와 통신하며,
/// EEG, PPG, 가속도계, 배터리 데이터를 실시간으로 수신합니다.
/// 델리게이트 패턴을 통해 상태 변화를 알립니다.
///
/// ## 기본 사용법
///
/// ```swift
/// let bluetoothKit = BluetoothKit()
/// bluetoothKit.delegate = self
///
/// // 1. 디바이스 스캔
/// bluetoothKit.startScanning()
///
/// // 2. 디바이스 연결
/// if let device = bluetoothKit.discoveredDevices.first {
///     bluetoothKit.connect(to: device)
/// }
///
/// // 3. 데이터 기록
/// bluetoothKit.startRecording()
///
/// // 4. 센서 데이터 접근
/// if let eeg = bluetoothKit.latestEEGReading {
///     print("EEG: \(eeg.channel1)µV, \(eeg.channel2)µV")
/// }
/// ```
@available(iOS 13.0, macOS 10.15, *)
public class BluetoothKit: @unchecked Sendable {
    
    // MARK: - Delegate
    
    /// BluetoothKit의 상태 변화를 받을 델리게이트
    public weak var delegate: BluetoothKitDelegate?
    
    // MARK: - Public Properties
    
    /// 스캔 중 발견된 Bluetooth 디바이스 목록.
    ///
    /// 이 배열은 스캔 중 새 디바이스가 발견될 때 자동으로 업데이트됩니다.
    /// 디바이스는 설정된 디바이스 이름 접두사로 필터링됩니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 발견된 디바이스 목록 표시
    /// ForEach(bluetoothKit.discoveredDevices, id: \.id) { device in
    ///     Button(device.name) {
    ///         bluetoothKit.connect(to: device)
    ///     }
    /// }
    ///
    /// // 특정 디바이스 연결
    /// if let targetDevice = bluetoothKit.discoveredDevices.first(where: { $0.name.contains("LinkBand") }) {
    ///     bluetoothKit.connect(to: targetDevice)
    /// }
    /// ```
    private(set) public var discoveredDevices: [BluetoothDevice] = [] {
        didSet {
            delegate?.bluetoothKit(self, didUpdateDevices: discoveredDevices)
        }
    }
    
    /// 현재 연결 상태의 사용자 친화적인 설명.
    ///
    /// 연결 상태를 사용자에게 표시하기 위한 한국어 문자열입니다:
    /// - "연결 안됨": 활성 연결 없음
    /// - "스캔 중...": 현재 디바이스 스캔 중  
    /// - "[디바이스명]에 연결 중...": 디바이스 연결 시도 중
    /// - "[디바이스명]에 연결됨": 디바이스에 성공적으로 연결됨
    /// - "[디바이스명]에 재연결 중...": 연결 해제 후 재연결 시도 중
    /// - "실패: [오류 메시지]": 연결 또는 작업 실패
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 상태바에 연결 상태 표시
    /// Text("상태: \(bluetoothKit.connectionStatusDescription)")
    ///     .foregroundColor(bluetoothKit.isConnected ? .green : .gray)
    ///
    /// // 연결 완료 감지
    /// if bluetoothKit.connectionStatusDescription.contains("연결됨") {
    ///     // 연결 완료 후 자동 작업 실행
    ///     bluetoothKit.startRecording()
    /// }
    /// ```
    private(set) public var connectionStatusDescription: String = "연결 안됨" {
        didSet {
            delegate?.bluetoothKit(self, didUpdateConnectionStatus: connectionStatusDescription)
        }
    }
    
    /// 라이브러리가 현재 디바이스를 스캔 중인지 여부.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 스캔 상태에 따른 UI 표시
    /// if bluetoothKit.isScanning {
    ///     Button("중지") { bluetoothKit.stopScanning() }
    /// } else {
    ///     Button("스캔 시작") { bluetoothKit.startScanning() }
    /// }
    /// ```
    private(set) public var isScanning: Bool = false {
        didSet {
            delegate?.bluetoothKit(self, didUpdateScanningState: isScanning)
        }
    }
    
    /// 데이터 기록이 현재 활성화되어 있는지 여부.
    ///
    /// `true`일 때, 수신된 모든 센서 데이터가 파일에 저장됩니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 기록 상태 확인
    /// if bluetoothKit.isRecording {
    ///     print("현재 기록 중...")
    /// }
    ///
    /// // SwiftUI에서 기록 버튼
    /// Button(bluetoothKit.isRecording ? "기록 중지" : "기록 시작") {
    ///     if bluetoothKit.isRecording {
    ///         bluetoothKit.stopRecording()
    ///     } else {
    ///         bluetoothKit.startRecording()
    ///     }
    /// }
    /// ```
    private(set) public var isRecording: Bool = false {
        didSet {
            delegate?.bluetoothKit(self, didUpdateRecordingState: isRecording)
        }
    }
    
    /// auto-reconnection이 현재 활성화되어 있는지 여부.
    ///
    /// `true`일 때, 연결이 끊어지면 라이브러리가 자동으로 재연결을 시도합니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 자동 재연결 토글
    /// Toggle("자동 재연결", isOn: $bluetoothKit.isAutoReconnectEnabled)
    ///
    /// // 설정에 따른 UI 표시
    /// if bluetoothKit.isAutoReconnectEnabled {
    ///     Image(systemName: "arrow.triangle.2.circlepath")
    ///         .foregroundColor(.blue)
    /// }
    /// ```
    public var isAutoReconnectEnabled: Bool = true {
        didSet {
            delegate?.bluetoothKit(self, didUpdateAutoReconnectState: isAutoReconnectEnabled)
            bluetoothManager.enableAutoReconnect(isAutoReconnectEnabled)
        }
    }
    
    // 최신 센서 읽기값
    
    /// 가장 최근의 EEG (뇌전도) 읽기값.
    ///
    /// 마이크로볼트(µV) 단위의 2채널 뇌 활동 데이터와 lead-off 상태를 포함합니다.
    /// 아직 EEG 데이터를 받지 못한 경우 `nil`입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // EEG 데이터 표시
    /// if let eeg = bluetoothKit.latestEEGReading {
    ///     Text("EEG: \(eeg.channel1)µV / \(eeg.channel2)µV")
    ///     Text("Lead-off: \(eeg.leadOff ? "감지됨" : "정상")")
    /// } else {
    ///     Text("EEG 데이터 없음")
    /// }
    /// ```
    private(set) public var latestEEGReading: EEGReading? {
        didSet {
            delegate?.bluetoothKit(self, didUpdateEEGReading: latestEEGReading)
        }
    }
    
    /// 가장 최근의 PPG (광전 용적 맥파) 읽기값.
    ///
    /// 심박수 모니터링을 위한 적색 및 적외선 LED 값을 포함합니다.
    /// 아직 PPG 데이터를 받지 못한 경우 `nil`입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // PPG 데이터 표시
    /// if let ppg = bluetoothKit.latestPPGReading {
    ///     VStack {
    ///         Text("Red: \(ppg.red)")
    ///         Text("IR: \(ppg.infrared)")
    ///         Text("심박수 계산 가능")
    ///     }
    /// } else {
    ///     Text("PPG 데이터 대기 중...")
    /// }
    /// ```
    private(set) public var latestPPGReading: PPGReading? {
        didSet {
            delegate?.bluetoothKit(self, didUpdatePPGReading: latestPPGReading)
        }
    }
    
    /// 가장 최근의 가속도계 읽기값.
    ///
    /// 모션 감지를 위한 3축 가속도 데이터를 포함합니다.
    /// 아직 가속도계 데이터를 받지 못한 경우 `nil`입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 가속도계 데이터 표시
    /// if let accel = bluetoothKit.latestAccelerometerReading {
    ///     HStack {
    ///         Text("X: \(String(format: "%.2f", accel.x))")
    ///         Text("Y: \(String(format: "%.2f", accel.y))")
    ///         Text("Z: \(String(format: "%.2f", accel.z))")
    ///     }
    /// }
    /// ```
    private(set) public var latestAccelerometerReading: AccelerometerReading? {
        didSet {
            delegate?.bluetoothKit(self, didUpdateAccelerometerReading: latestAccelerometerReading)
        }
    }
    
    /// 가장 최근의 배터리 레벨 읽기값.
    ///
    /// 연결된 디바이스의 배터리 백분율(0-100%)을 포함합니다.
    /// 아직 배터리 데이터를 받지 못한 경우 `nil`입니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 배터리 레벨 표시
    /// if let battery = bluetoothKit.latestBatteryReading {
    ///     HStack {
    ///         Image(systemName: "battery.75")
    ///         Text("\(battery.level)%")
    ///     }
    /// }
    /// ```
    private(set) public var latestBatteryReading: BatteryReading? {
        didSet {
            delegate?.bluetoothKit(self, didUpdateBatteryReading: latestBatteryReading)
        }
    }
    
    /// 기록된 파일 목록.
    ///
    /// Documents 디렉토리에 저장된 센서 데이터 파일들의 URL 목록입니다.
    /// 파일은 타임스탬프와 센서 타입으로 구분됩니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 기록된 파일 목록 표시
    /// ForEach(bluetoothKit.recordedFiles, id: \.self) { file in
    ///     Text(file.lastPathComponent)
    /// }
    ///
    /// // 최신 파일 확인
    /// if let latestFile = bluetoothKit.recordedFiles.last {
    ///     print("최신 파일: \(latestFile.lastPathComponent)")
    /// }
    /// ```
    private(set) public var recordedFiles: [URL] = [] {
        didSet {
            delegate?.bluetoothKit(self, didUpdateRecordedFiles: recordedFiles)
        }
    }
    
    /// Bluetooth가 비활성화되어 있는지 여부.
    ///
    /// iOS에서 Bluetooth가 꺼져 있으면 `true`가 됩니다.
    /// 이 상태에서는 스캔이나 연결이 불가능합니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // Bluetooth 상태에 따른 UI 조건부 표시
    /// if bluetoothKit.isBluetoothDisabled {
    ///     Text("Bluetooth를 켜주세요")
    ///         .foregroundColor(.red)
    /// }
    ///
    /// // 스캔 버튼 비활성화
    /// Button("스캔 시작") { }
    ///     .disabled(bluetoothKit.isBluetoothDisabled)
    /// ```
    private(set) public var isBluetoothDisabled: Bool = false {
        didSet {
            delegate?.bluetoothKit(self, didUpdateBluetoothDisabled: isBluetoothDisabled)
        }
    }
    
    /// 현재 연결 상태 (내부에서만 설정 가능)
    private(set) public var connectionState: ConnectionState = .disconnected {
        didSet {
            delegate?.bluetoothKit(self, didUpdateConnectionState: connectionState)
        }
    }
    
    /// 가속도계 표시 모드
    public var accelerometerMode: AccelerometerMode = .raw {
        didSet {
            delegate?.bluetoothKit(self, didUpdateAccelerometerMode: accelerometerMode)
        }
    }
    
    // MARK: - Batch Data Configuration Properties
    
    /// 선택된 수집 모드
    public var batchSelectedCollectionMode: BatchDataConfigurationManager.CollectionMode {
        return batchDataConfigurationManager.selectedCollectionMode
    }
    
    /// 선택된 센서들
    public var batchSelectedSensors: Set<SensorType> {
        return batchDataConfigurationManager.selectedSensors
    }
    
    /// 배치 데이터 모니터링 활성화 상태
    public var isBatchMonitoringActive: Bool {
        return batchDataConfigurationManager.isMonitoringActive
    }
    
    /// 경고 팝업 표시 상태
    public var showBatchRecordingChangeWarning: Bool {
        return batchDataConfigurationManager.showRecordingChangeWarning
    }
    
    /// 펜딩된 센서 선택 (하위 호환성을 위해 유지)
    public var batchPendingSensorSelection: Set<SensorType>? {
        return batchDataConfigurationManager.pendingSensorSelection
    }
    
    /// 펜딩된 설정 변경
    public var batchPendingConfigurationChange: BatchDataConfigurationManager.PendingConfigurationChange? {
        return batchDataConfigurationManager.pendingConfigurationChange
    }
    
    // MARK: - Batch Data Collection
    
    /// 배치 단위로 센서 데이터를 수신하는 델리게이트.
    ///
    /// 설정된 시간 간격이나 샘플 개수에 따라 센서 데이터를 배치로 받을 수 있습니다.
    /// 개별 샘플 대신 배치로 처리하면 성능이 향상되고 더 효율적인 데이터 분석이 가능합니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// class DataProcessor: SensorBatchDataDelegate {
    ///     func didReceiveEEGBatch(_ readings: [EEGReading]) {
    ///         print("EEG 배치: \(readings.count)개 샘플")
    ///     }
    /// }
    ///
    /// bluetoothKit.batchDataDelegate = DataProcessor()
    /// bluetoothKit.setDataCollection(timeInterval: 0.5, for: .eeg)
    /// ```
    public weak var batchDataDelegate: SensorBatchDataDelegate?
    
    // MARK: - Internal Properties
    
    /// 각 센서별 데이터 수집 설정
    private var dataCollectionConfigs: [SensorType: DataCollectionConfig] = [:]
    
    /// 현재 선택된 센서 타입들 (모니터링할 센서들)
    private var selectedSensors: Set<SensorType> = [.eeg, .ppg, .accelerometer]
    
    /// 센서별 데이터 버퍼 (샘플 기반 모드용)
    private var eegBuffer: [EEGReading] = []
    private var ppgBuffer: [PPGReading] = []
    private var accelerometerBuffer: [AccelerometerReading] = []
    
    /// 시간 기반 배치 관리자들
    private var eegTimeBatchManager: TimeBatchManager<EEGReading>?
    private var ppgTimeBatchManager: TimeBatchManager<PPGReading>?
    private var accelerometerTimeBatchManager: TimeBatchManager<AccelerometerReading>?
    
    // 가속도계 모드 처리용 중력 추정값 (DataRecorder와 동기화)
    private var gravityX: Double = 0
    private var gravityY: Double = 0
    private var gravityZ: Double = 0
    private var isGravityInitialized = false
    private let gravityFilterFactor: Double = 0.1
    
    // MARK: - Private Components
    
    private let bluetoothManager: BluetoothManager
    private let dataRecorder: DataRecorder
    private lazy var batchDataConfigurationManager: BatchDataConfigurationManager = {
        return BatchDataConfigurationManager(bluetoothKit: self)
    }()
    private let sensorDataParser: SensorDataParser
    private let configuration: SensorConfiguration
    private let logger: InternalLogger
    
    // MARK: - Time-based Batch Manager
    
    /// 시간 기반 배치 관리를 위한 제네릭 클래스
    private class TimeBatchManager<T> where T: Sendable {
        private var buffer: [T] = []
        private var batchStartTime: Date?
        private let targetInterval: TimeInterval
        private let timestampExtractor: (T) -> Date
        
        init(timeInterval: TimeInterval, timestampExtractor: @escaping (T) -> Date) {
            self.targetInterval = timeInterval
            self.timestampExtractor = timestampExtractor
        }
        
        /// 샘플을 추가하고 배치가 완성되면 반환
        func addSample(_ sample: T) -> [T]? {
            let sampleTime = timestampExtractor(sample)
            
            // 첫 번째 샘플이면 배치 시작 시간 설정
            if batchStartTime == nil {
                batchStartTime = sampleTime
            }
            
            buffer.append(sample)
            
            // 시간 간격 확인
            let elapsed = sampleTime.timeIntervalSince(batchStartTime!)
            
            if elapsed >= targetInterval {
                let batch = buffer
                buffer.removeAll()
                batchStartTime = sampleTime  // 새로운 배치 시작
                return batch
            }
            
            return nil
        }
        
        /// 현재 버퍼 상태 리셋
        func reset() {
            buffer.removeAll()
            batchStartTime = nil
        }
        
        /// 현재 버퍼의 샘플 개수
        var currentBufferCount: Int {
            return buffer.count
        }
        
        /// 현재 배치의 경과 시간
        var currentElapsed: TimeInterval? {
            guard let startTime = batchStartTime, !buffer.isEmpty else { return nil }
            let lastSampleTime = timestampExtractor(buffer.last!)
            return lastSampleTime.timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Initialization
    
    /// 새로운 BluetoothKit 인스턴스를 생성합니다.
    /// 
    /// 기본 설정으로 초기화되며, 바로 사용할 수 있습니다.
    ///
    /// ## 예시
    /// ```swift
    /// let bluetoothKit = BluetoothKit()
    /// bluetoothKit.startScanning()
    /// ```
    public init() {
        self.configuration = .default
        self.logger = InternalLogger(isEnabled: false)  // 프로덕션 최적화
        self.bluetoothManager = BluetoothManager(configuration: configuration, logger: logger)
        self.dataRecorder = DataRecorder(logger: logger)
        self.sensorDataParser = SensorDataParser(configuration: configuration)
        
        // 기본값: auto-reconnect 활성화 (대부분의 경우 유용함)
        self.isAutoReconnectEnabled = true
        
        setupDelegates()
        updateRecordedFiles()
        
        // BatchDataConfigurationManager delegate 설정 (lazy 프로퍼티 초기화 후)
        setupBatchConfigurationDelegate()
        
        // BluetoothManager에 초기 auto-reconnect 설정 전달
        bluetoothManager.enableAutoReconnect(true)
    }
    
    // MARK: - Public Interface
    
    /// Bluetooth 디바이스 스캔을 시작합니다.
    ///
    /// ## 예시
    /// ```swift
    /// bluetoothKit.startScanning()
    /// ```
    public func startScanning() {
        bluetoothManager.startScanning()
    }
    
    /// Bluetooth 디바이스 스캔을 중지합니다.
    ///
    /// ## 예시
    /// ```swift
    /// bluetoothKit.stopScanning()
    /// ```
    public func stopScanning() {
        bluetoothManager.stopScanning()
    }
    
    /// 특정 Bluetooth 디바이스에 연결합니다.
    ///
    /// - Parameter device: 연결할 디바이스
    ///
    /// ## 예시
    /// ```swift
    /// if let device = bluetoothKit.discoveredDevices.first(where: { $0.name.contains("LinkBand") }) {
    ///     bluetoothKit.connect(to: device)
    /// }
    /// ```
    public func connect(to device: BluetoothDevice) {
        bluetoothManager.connect(to: device)
    }
    
    /// 현재 연결된 디바이스에서 연결을 해제합니다.
    ///
    /// ## 예시
    /// ```swift
    /// bluetoothKit.disconnect()
    /// ```
    public func disconnect() {
        if isRecording {
            stopRecording()
        }
        bluetoothManager.disconnect()
    }
    
    /// 센서 데이터를 파일로 기록하기 시작합니다.
    ///
    /// ## 예시
    /// ```swift
    /// bluetoothKit.startRecording()
    /// ```
    public func startRecording() {
        // 현재 설정된 센서 타입들만 기록하도록 전달
        let selectedSensors = Set(dataCollectionConfigs.keys)
        dataRecorder.startRecording(with: selectedSensors)
    }
    
    /// 선택된 센서들과 함께 센서 데이터 기록을 시작합니다.
    ///
    /// - Parameter selectedSensors: 기록할 센서 타입들의 집합
    ///
    /// ## 예시
    /// ```swift
    /// // EEG와 PPG만 기록
    /// bluetoothKit.startRecording(with: [.eeg, .ppg])
    /// 
    /// // 모든 센서 기록
    /// bluetoothKit.startRecording(with: [.eeg, .ppg, .accelerometer])
    /// ```
    public func startRecording(with selectedSensors: Set<SensorType>) {
        dataRecorder.startRecording(with: selectedSensors)
    }
    
    /// 센서 데이터 기록을 중지합니다.
    ///
    /// ## 예시
    /// ```swift
    /// bluetoothKit.stopRecording()
    /// ```
    public func stopRecording() {
        dataRecorder.stopRecording()
    }
    
    /// 기록 중에 선택된 센서를 업데이트합니다.
    ///
    /// 기록 중이 아닌 경우 아무 작업도 수행하지 않습니다.
    /// 새로 선택된 센서만 향후 데이터가 기록됩니다.
    ///
    /// - Parameter selectedSensors: 기록할 센서 타입들의 집합
    ///
    /// ## 예시
    /// ```swift
    /// // 기록 중에 센서 선택 변경
    /// bluetoothKit.updateRecordingSensors([.eeg, .accelerometer])
    /// ```
    public func updateRecordingSensors(_ selectedSensors: Set<SensorType>) {
        dataRecorder.updateSelectedSensors(selectedSensors)
    }
    
    /// 기록된 파일들의 URL 목록을 반환합니다.
    ///
    /// - Returns: 문서 디렉토리에 저장된 모든 기록 파일들의 URL 배열
    ///
    /// ## 예시
    /// ```swift
    /// let files = bluetoothKit.getRecordedFiles()
    /// print("기록된 파일 개수: \(files.count)")
    /// 
    /// // 파일 공유
    /// let activityViewController = UIActivityViewController(
    ///     activityItems: files,
    ///     applicationActivities: nil
    /// )
    /// ```
    public func getRecordedFiles() -> [URL] {
        return dataRecorder.getRecordedFiles()
    }
    
    /// EEG 데이터를 직접 기록합니다.
    ///
    /// 일반적으로 자동으로 기록되지만, 커스텀 데이터 처리 후 수동으로 기록할 때 사용합니다.
    ///
    /// - Parameter readings: 기록할 EEG 읽기값 배열
    ///
    /// ## 예시
    /// ```swift
    /// let processedReadings = filterEEGData(originalReadings)
    /// bluetoothKit.recordEEGData(processedReadings)
    /// ```
    public func recordEEGData(_ readings: [EEGReading]) {
        dataRecorder.recordEEGData(readings)
    }
    
    /// PPG 데이터를 직접 기록합니다.
    ///
    /// 일반적으로 자동으로 기록되지만, 커스텀 데이터 처리 후 수동으로 기록할 때 사용합니다.
    ///
    /// - Parameter readings: 기록할 PPG 읽기값 배열
    ///
    /// ## 예시
    /// ```swift
    /// let processedReadings = filterPPGData(originalReadings)
    /// bluetoothKit.recordPPGData(processedReadings)
    /// ```
    public func recordPPGData(_ readings: [PPGReading]) {
        dataRecorder.recordPPGData(readings)
    }
    
    /// 가속도계 데이터를 직접 기록합니다.
    ///
    /// 일반적으로 자동으로 기록되지만, 커스텀 데이터 처리 후 수동으로 기록할 때 사용합니다.
    ///
    /// - Parameter readings: 기록할 가속도계 읽기값 배열
    ///
    /// ## 예시
    /// ```swift
    /// let processedReadings = filterAccelerometerData(originalReadings)
    /// bluetoothKit.recordAccelerometerData(processedReadings)
    /// ```
    public func recordAccelerometerData(_ readings: [AccelerometerReading]) {
        dataRecorder.recordAccelerometerData(readings)
    }
    
    /// 배터리 데이터를 직접 기록합니다.
    ///
    /// 일반적으로 자동으로 기록되지만, 수동으로 기록할 때 사용합니다.
    ///
    /// - Parameter reading: 기록할 배터리 읽기값
    ///
    /// ## 예시
    /// ```swift
    /// bluetoothKit.recordBatteryData(batteryReading)
    /// ```
    public func recordBatteryData(_ reading: BatteryReading) {
        dataRecorder.recordBatteryData(reading)
    }
    
    /// 데이터 기록 이벤트를 처리하는 델리게이트입니다.
    ///
    /// 기록 시작, 중지, 오류 등의 이벤트를 받으려면 이 델리게이트를 설정하세요.
    ///
    /// ## 예시
    /// ```swift
    /// class RecordingHandler: DataRecorderDelegate {
    ///     func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date) {
    ///         print("기록 시작됨")
    ///     }
    ///     
    ///     func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL]) {
    ///         print("기록 완료: \(savedFiles.count)개 파일")
    ///     }
    /// }
    /// 
    /// bluetoothKit.dataRecorderDelegate = RecordingHandler()
    /// ```
    public weak var dataRecorderDelegate: DataRecorderDelegate? {
        get { return dataRecorder.delegate }
        set { dataRecorder.delegate = newValue }
    }
    
    /// 기록이 저장되는 디렉토리를 가져옵니다.
    ///
    /// - Returns: CSV 및 JSON 파일이 저장되는 documents 디렉토리의 URL.
    ///
    /// 기록된 파일에 프로그래밍적으로 접근하거나 공유 기능을 위해 사용하세요.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 기록 디렉토리 경로 표시
    /// Text("저장 위치: \(bluetoothKit.recordingsDirectory.path)")
    ///
    /// // 파일 공유
    /// let activityViewController = UIActivityViewController(
    ///     activityItems: [bluetoothKit.recordingsDirectory],
    ///     applicationActivities: nil
    /// )
    /// ```
    public var recordingsDirectory: URL {
        return dataRecorder.recordingsDirectory
    }
    
    /// 현재 디바이스에 연결되어 있는지 확인합니다.
    ///
    /// - Returns: 디바이스가 연결되어 데이터 스트리밍 준비가 되었으면 `true`.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // 연결 상태에 따른 UI 표시
    /// Circle()
    ///     .fill(bluetoothKit.isConnected ? Color.green : Color.red)
    ///     .frame(width: 10, height: 10)
    ///
    /// // 연결 상태에 따른 버튼 활성화
    /// Button("기록 시작") { }
    ///     .disabled(!bluetoothKit.isConnected)
    /// ```
    public var isConnected: Bool {
        return bluetoothManager.isConnected
    }
    
    // MARK: - Sensor Monitoring Control
    
    /// 센서 모니터링을 활성화합니다.
    ///
    /// 연결된 디바이스로부터 선택된 센서의 데이터 수신을 시작합니다.
    /// 모니터링이 활성화되면 최신 센서 데이터가 실시간으로 업데이트됩니다.
    ///
    /// ## 예시
    /// ```swift
    /// // 센서 선택 후 모니터링 시작
    /// bluetoothKit.setSelectedSensors([.eeg, .ppg])
    /// bluetoothKit.enableMonitoring()
    /// ```
    public func enableMonitoring() {
        bluetoothManager.enableMonitoring()
    }
    
    /// 센서 모니터링을 비활성화합니다.
    ///
    /// 모든 센서의 데이터 수신을 중지합니다 (배터리 센서 제외).
    /// 최신 센서 데이터 업데이트가 중단되고 모든 데이터 버퍼가 클리어됩니다.
    ///
    /// ## 예시
    /// ```swift
    /// bluetoothKit.disableMonitoring()
    /// ```
    public func disableMonitoring() {
        // 모든 센서 수신 중단 (배터리 제외)
        selectedSensors = []
        bluetoothManager.disableMonitoring()
        
        // 모든 센서 데이터 버퍼 클리어
        clearAllBuffers()
        
        // 배치 데이터 수집도 중단
        disableAllDataCollection()
        
        // 최신 센서 데이터도 클리어 (배터리 제외)
        latestEEGReading = nil
        latestPPGReading = nil
        latestAccelerometerReading = nil
    }
    
    /// 모니터링할 센서 타입을 설정합니다.
    ///
    /// 지정된 센서들만 데이터를 수신하고 배치 수집이나 기록에 포함됩니다.
    /// 연결 상태와 관계없이 설정할 수 있으며, 연결 후 자동으로 적용됩니다.
    ///
    /// - Parameter sensors: 모니터링할 센서 타입들의 집합
    ///
    /// ## 예시
    /// ```swift
    /// // EEG와 PPG만 모니터링
    /// bluetoothKit.setSelectedSensors([.eeg, .ppg])
    ///
    /// // 모든 센서 모니터링
    /// bluetoothKit.setSelectedSensors([.eeg, .ppg, .accelerometer])
    ///
    /// // 센서 모니터링 없음 (배터리만)
    /// bluetoothKit.setSelectedSensors([])
    /// ```
    public func setSelectedSensors(_ sensors: Set<SensorType>) {
        selectedSensors = sensors
        bluetoothManager.setSelectedSensors(sensors)
    }
    
    // MARK: - Batch Data Collection API
    
    /// 시간 간격을 기준으로 배치 데이터 수집을 설정합니다.
    ///
    /// 지정된 시간마다 해당 센서의 데이터를 배치로 수집하여 델리게이트에 전달합니다.
    /// 시간 간격은 센서의 샘플링 레이트에 따라 적절한 샘플 개수로 자동 변환됩니다.
    ///
    /// - Parameters:
    ///   - timeInterval: 배치 수집 간격 (초 단위, 0.04 ~ 10.0초)
    ///   - sensorType: 설정할 센서 타입
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // EEG 데이터를 0.5초마다 배치로 수집 (125개 샘플)
    /// bluetoothKit.setDataCollection(timeInterval: 0.5, for: .eeg)
    ///
    /// // PPG 데이터를 1초마다 배치로 수집 (50개 샘플)
    /// bluetoothKit.setDataCollection(timeInterval: 1.0, for: .ppg)
    ///
    /// // 가속도계 데이터를 2초마다 배치로 수집 (60개 샘플)
    /// bluetoothKit.setDataCollection(timeInterval: 2.0, for: .accelerometer)
    /// ```
    public func setDataCollection(timeInterval: TimeInterval, for sensorType: SensorType) {
        let config = DataCollectionConfig(sensorType: sensorType, timeInterval: timeInterval)
        dataCollectionConfigs[sensorType] = config
        clearBuffer(for: sensorType)
        
        print("🔧 시간 기반 배치 설정: \(sensorType) - \(timeInterval)초 간격")
        
        // 시간 기반 배치 관리자 초기화
        switch sensorType {
        case .eeg:
            eegTimeBatchManager = TimeBatchManager<EEGReading>(timeInterval: timeInterval) { $0.timestamp }
            print("📊 EEG TimeBatchManager 초기화됨")
        case .ppg:
            ppgTimeBatchManager = TimeBatchManager<PPGReading>(timeInterval: timeInterval) { $0.timestamp }
            print("📊 PPG TimeBatchManager 초기화됨")
        case .accelerometer:
            accelerometerTimeBatchManager = TimeBatchManager<AccelerometerReading>(timeInterval: timeInterval) { $0.timestamp }
            print("📊 ACC TimeBatchManager 초기화됨")
        case .battery:
            break // 배터리는 배치 처리하지 않음
        }
    }
    
    /// 샘플 개수를 기준으로 배치 데이터 수집을 설정합니다.
    ///
    /// 지정된 개수의 샘플이 누적되면 배치로 수집하여 델리게이트에 전달합니다.
    /// 정확한 샘플 개수 제어가 필요한 신호 처리나 분석에 유용합니다.
    ///
    /// - Parameters:
    ///   - sampleCount: 배치당 샘플 개수 (1 ~ 각 센서별 최대값)
    ///   - sensorType: 설정할 센서 타입
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // EEG 데이터를 100개씩 배치로 수집
    /// bluetoothKit.setDataCollection(sampleCount: 100, for: .eeg)
    ///
    /// // PPG 데이터를 25개씩 배치로 수집
    /// bluetoothKit.setDataCollection(sampleCount: 25, for: .ppg)
    ///
    /// // 가속도계 데이터를 15개씩 배치로 수집
    /// bluetoothKit.setDataCollection(sampleCount: 15, for: .accelerometer)
    /// ```
    public func setDataCollection(sampleCount: Int, for sensorType: SensorType) {
        let config = DataCollectionConfig(sensorType: sensorType, sampleCount: sampleCount)
        dataCollectionConfigs[sensorType] = config
        clearBuffer(for: sensorType)
        
        // 샘플 기반 모드에서는 시간 기반 관리자 제거
        switch sensorType {
        case .eeg:
            eegTimeBatchManager = nil
        case .ppg:
            ppgTimeBatchManager = nil
        case .accelerometer:
            accelerometerTimeBatchManager = nil
        case .battery:
            break
        }
    }
    
    /// 특정 센서의 배치 데이터 수집을 비활성화합니다.
    ///
    /// 해당 센서는 기본 동작(latest* 프로퍼티 업데이트)만 수행하고
    /// 배치 델리게이트 호출은 중단됩니다.
    ///
    /// - Parameter sensorType: 비활성화할 센서 타입
    ///
    /// ## 예시
    ///
    /// ```swift
    /// // EEG 배치 수집 중단
    /// bluetoothKit.disableDataCollection(for: .eeg)
    /// ```
    public func disableDataCollection(for sensorType: SensorType) {
        dataCollectionConfigs.removeValue(forKey: sensorType)
        clearBuffer(for: sensorType)
    }
    
    /// 모든 센서의 배치 데이터 수집을 비활성화합니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// bluetoothKit.disableAllDataCollection()
    /// ```
    public func disableAllDataCollection() {
        dataCollectionConfigs.removeAll()
        clearAllBuffers()
    }
    
    // MARK: - Private Setup
    
    /// 지정된 센서의 데이터 버퍼를 초기화합니다.
    private func clearBuffer(for sensorType: SensorType) {
        switch sensorType {
        case .eeg:
            eegBuffer.removeAll()
            eegTimeBatchManager?.reset()
        case .ppg:
            ppgBuffer.removeAll()
            ppgTimeBatchManager?.reset()
        case .accelerometer:
            accelerometerBuffer.removeAll()
            accelerometerTimeBatchManager?.reset()
        case .battery:
            break // 배터리는 버퍼가 없음
        }
    }
    
    /// 모든 센서 버퍼를 초기화합니다.
    private func clearAllBuffers() {
        eegBuffer.removeAll()
        ppgBuffer.removeAll()
        accelerometerBuffer.removeAll()
    }
    
    /// EEG 데이터를 버퍼에 추가하고 배치 조건을 확인합니다.
    private func addToEEGBuffer(_ reading: EEGReading) {
        guard let config = dataCollectionConfigs[.eeg] else { return }
        
        switch config.mode {
        case .timeInterval(let interval):
            // 시간 기반 모드: TimeBatchManager 사용
            if let timeBatchManager = eegTimeBatchManager,
               let batch = timeBatchManager.addSample(reading) {
                DispatchQueue.main.async { [weak self] in
                    self?.batchDataDelegate?.didReceiveEEGBatch(batch)
                }
            }
            
        case .sampleCount(let targetCount):
            // 샘플 기반 모드: 기존 버퍼 사용
            eegBuffer.append(reading)
            
            if eegBuffer.count >= targetCount {
                let batch = Array(eegBuffer.prefix(targetCount))
                eegBuffer.removeFirst(targetCount)
                
                DispatchQueue.main.async { [weak self] in
                    self?.batchDataDelegate?.didReceiveEEGBatch(batch)
                }
            }
        }
    }
    
    /// PPG 데이터를 버퍼에 추가하고 배치 조건을 확인합니다.
    private func addToPPGBuffer(_ reading: PPGReading) {
        guard let config = dataCollectionConfigs[.ppg] else { return }
        
        switch config.mode {
        case .timeInterval(let interval):
            // 시간 기반 모드: TimeBatchManager 사용
            if let timeBatchManager = ppgTimeBatchManager,
               let batch = timeBatchManager.addSample(reading) {
                DispatchQueue.main.async { [weak self] in
                    self?.batchDataDelegate?.didReceivePPGBatch(batch)
                }
            }
            
        case .sampleCount(let targetCount):
            // 샘플 기반 모드: 기존 버퍼 사용
            ppgBuffer.append(reading)
            
            if ppgBuffer.count >= targetCount {
                let batch = Array(ppgBuffer.prefix(targetCount))
                ppgBuffer.removeFirst(targetCount)
                
                DispatchQueue.main.async { [weak self] in
                    self?.batchDataDelegate?.didReceivePPGBatch(batch)
                }
            }
        }
    }
    
    /// 가속도계 데이터를 버퍼에 추가하고 배치 조건을 확인합니다.
    private func addToAccelerometerBuffer(_ reading: AccelerometerReading) {
        guard let config = dataCollectionConfigs[.accelerometer] else { return }
        
        switch config.mode {
        case .timeInterval(let interval):
            // 시간 기반 모드: TimeBatchManager 사용
            if let timeBatchManager = accelerometerTimeBatchManager,
               let batch = timeBatchManager.addSample(reading) {
                DispatchQueue.main.async { [weak self] in
                    self?.batchDataDelegate?.didReceiveAccelerometerBatch(batch)
                }
            }
            
        case .sampleCount(let targetCount):
            // 샘플 기반 모드: 기존 버퍼 사용
            accelerometerBuffer.append(reading)
            
            if accelerometerBuffer.count >= targetCount {
                let batch = Array(accelerometerBuffer.prefix(targetCount))
                accelerometerBuffer.removeFirst(targetCount)
                
                DispatchQueue.main.async { [weak self] in
                    self?.batchDataDelegate?.didReceiveAccelerometerBatch(batch)
                }
            }
        }
    }
    
    private func setupDelegates() {
        bluetoothManager.delegate = self
        bluetoothManager.sensorDataDelegate = self
        dataRecorder.delegate = self
        // batchDataConfigurationManager.delegate는 lazy 프로퍼티이므로 별도로 설정
    }
    
    private func setupBatchConfigurationDelegate() {
        batchDataConfigurationManager.delegate = self
    }
    
    private func updateRecordedFiles() {
        recordedFiles = dataRecorder.getRecordedFiles()
    }
    
    /// 자동 재연결 기능을 설정합니다.
    public func setAutoReconnect(enabled: Bool) {
        isAutoReconnectEnabled = enabled
    }
    
    /// 내부 로깅 메서드
    private func log(_ message: String) {
        logger.log(message)
    }
    
    /// 중력 성분을 추정하고 업데이트하는 함수 (움직임 모드용)
    private func updateGravityEstimate(_ reading: AccelerometerReading) {
        if !isGravityInitialized {
            // 첫 번째 읽기: 초기값으로 설정
            gravityX = Double(reading.x)
            gravityY = Double(reading.y)
            gravityZ = Double(reading.z)
            isGravityInitialized = true
        } else {
            // 저역 통과 필터를 사용한 중력 추정
            gravityX = gravityX * (1 - gravityFilterFactor) + Double(reading.x) * gravityFilterFactor
            gravityY = gravityY * (1 - gravityFilterFactor) + Double(reading.y) * gravityFilterFactor
            gravityZ = gravityZ * (1 - gravityFilterFactor) + Double(reading.z) * gravityFilterFactor
        }
    }
    
    /// 가속도계 모드에 따라 처리된 데이터를 생성합니다.
    private func processAccelerometerReading(_ reading: AccelerometerReading) -> AccelerometerReading {
        if accelerometerMode == .raw {
            // 원시값 모드: 원래 데이터 그대로 반환
            return reading
        } else {
            // 움직임 모드: 중력 제거된 선형 가속도 반환
            updateGravityEstimate(reading)
            let linearX = Int16(Double(reading.x) - gravityX)
            let linearY = Int16(Double(reading.y) - gravityY)
            let linearZ = Int16(Double(reading.z) - gravityZ)
            
            return AccelerometerReading(x: linearX, y: linearY, z: linearZ, timestamp: reading.timestamp)
        }
    }
    
    /// 현재 모니터링 중인 센서 타입들을 반환합니다.
    ///
    /// - Returns: 현재 선택된 센서 타입들의 집합
    ///
    /// ## 예시
    /// ```swift
    /// let selectedSensors = bluetoothKit.selectedSensorTypes
    /// if selectedSensors.contains(.eeg) {
    ///     print("EEG 센서 모니터링 중")
    /// }
    /// ```
    public var selectedSensorTypes: Set<SensorType> {
        return selectedSensors
    }
    
    // MARK: - Batch Data Configuration Methods
    
    /// 배치 데이터 모니터링을 시작합니다.
    public func startBatchMonitoring() {
        batchDataConfigurationManager.startMonitoring()
    }
    
    /// 배치 데이터 모니터링을 중지합니다.
    public func stopBatchMonitoring() {
        batchDataConfigurationManager.stopMonitoring()
    }
    
    /// 배치 데이터 센서 선택을 업데이트합니다.
    public func updateBatchSensorSelection(_ sensors: Set<SensorType>) {
        batchDataConfigurationManager.updateSensorSelection(sensors)
    }
    
    /// 사용자가 경고 팝업에서 "기록 중지 후 변경"을 선택했을 때 호출합니다.
    public func confirmBatchSensorChangeWithRecordingStop() {
        batchDataConfigurationManager.confirmSensorChangeWithRecordingStop()
    }
    
    /// 사용자가 경고 팝업에서 "취소"를 선택했을 때 호출합니다.
    public func cancelBatchSensorChange() {
        batchDataConfigurationManager.cancelSensorChange()
    }
    
    /// 배치 데이터 수집 모드를 업데이트합니다.
    public func updateBatchCollectionMode(_ mode: BatchDataConfigurationManager.CollectionMode) {
        batchDataConfigurationManager.updateCollectionMode(mode)
    }
    
    // MARK: - Batch Sensor Configuration Access
    
    /// 특정 센서의 샘플 수를 반환합니다.
    public func getBatchSampleCount(for sensor: SensorType) -> Int {
        return batchDataConfigurationManager.getSampleCount(for: sensor)
    }
    
    /// 특정 센서의 시간(초)을 반환합니다.
    public func getBatchSeconds(for sensor: SensorType) -> Int {
        return batchDataConfigurationManager.getSeconds(for: sensor)
    }
    
    /// 특정 센서의 샘플 수 텍스트를 반환합니다.
    public func getBatchSampleCountText(for sensor: SensorType) -> String {
        return batchDataConfigurationManager.getSampleCountText(for: sensor)
    }
    
    /// 특정 센서의 시간 텍스트를 반환합니다.
    public func getBatchSecondsText(for sensor: SensorType) -> String {
        return batchDataConfigurationManager.getSecondsText(for: sensor)
    }
    
    /// 특정 센서의 분을 반환합니다.
    public func getBatchMinutes(for sensor: SensorType) -> Int {
        return batchDataConfigurationManager.getMinutes(for: sensor)
    }
    
    /// 특정 센서의 분 텍스트를 반환합니다.
    public func getBatchMinutesText(for sensor: SensorType) -> String {
        return batchDataConfigurationManager.getMinutesText(for: sensor)
    }
    
    /// 특정 센서의 샘플 수를 설정합니다.
    public func setBatchSampleCount(_ value: Int, for sensor: SensorType) {
        batchDataConfigurationManager.setSampleCount(value, for: sensor)
    }
    
    /// 특정 센서의 시간을 설정합니다.
    public func setBatchSeconds(_ value: Int, for sensor: SensorType) {
        batchDataConfigurationManager.setSeconds(value, for: sensor)
    }
    
    /// 특정 센서의 분을 설정합니다.
    public func setBatchMinutes(_ value: Int, for sensor: SensorType) {
        batchDataConfigurationManager.setMinutes(value, for: sensor)
    }
    
    /// 특정 센서의 샘플 수 텍스트를 설정합니다.
    public func setBatchSampleCountText(_ text: String, for sensor: SensorType) {
        batchDataConfigurationManager.setSampleCountText(text, for: sensor)
    }
    
    /// 특정 센서의 시간 텍스트를 설정합니다.
    public func setBatchSecondsText(_ text: String, for sensor: SensorType) {
        batchDataConfigurationManager.setSecondsText(text, for: sensor)
    }
    
    /// 특정 센서의 분 텍스트를 설정합니다.
    public func setBatchMinutesText(_ text: String, for sensor: SensorType) {
        batchDataConfigurationManager.setMinutesText(text, for: sensor)
    }
    
    // MARK: - Batch Validation Methods
    
    /// 샘플 수 유효성 검사를 수행합니다.
    public func validateBatchSampleCount(_ text: String, for sensor: SensorType) -> BatchDataConfigurationManager.ValidationResult {
        return batchDataConfigurationManager.validateSampleCount(text, for: sensor)
    }
    
    /// 시간 유효성 검사를 수행합니다.
    public func validateBatchSeconds(_ text: String, for sensor: SensorType) -> BatchDataConfigurationManager.ValidationResult {
        return batchDataConfigurationManager.validateSeconds(text, for: sensor)
    }
    
    /// 분 유효성 검사를 수행합니다.
    public func validateBatchMinutes(_ text: String, for sensor: SensorType) -> BatchDataConfigurationManager.ValidationResult {
        return batchDataConfigurationManager.validateMinutes(text, for: sensor)
    }
    
    // MARK: - Batch Helper Methods
    
    /// 특정 센서와 샘플 수에 대한 예상 시간을 반환합니다.
    public func getBatchExpectedTime(for sensor: SensorType, sampleCount: Int) -> Double {
        return batchDataConfigurationManager.getExpectedTime(for: sensor, sampleCount: sampleCount)
    }
    
    /// 특정 센서와 시간에 대한 예상 샘플 수를 반환합니다.
    public func getBatchExpectedSamples(for sensor: SensorType, seconds: Int) -> Int {
        return batchDataConfigurationManager.getExpectedSamples(for: sensor, seconds: seconds)
    }
    
    /// 특정 센서와 분에 대한 예상 샘플 수를 반환합니다.
    public func getBatchExpectedSamplesForMinutes(for sensor: SensorType, minutes: Int) -> Int {
        return batchDataConfigurationManager.getExpectedSamples(for: sensor, minutes: minutes)
    }
    
    /// 특정 센서와 샘플 수에 대한 예상 분을 반환합니다.
    public func getBatchExpectedMinutes(for sensor: SensorType, sampleCount: Int) -> Double {
        return batchDataConfigurationManager.getExpectedMinutes(for: sensor, sampleCount: sampleCount)
    }
    
    /// 모든 배치 센서 설정을 기본값으로 리셋합니다.
    public func resetBatchToDefaults() {
        batchDataConfigurationManager.resetToDefaults()
    }
    
    /// 배치 설정 상태 요약을 반환합니다.
    public func getBatchConfigurationSummary() -> String {
        return batchDataConfigurationManager.getConfigurationSummary()
    }
    
    /// 특정 센서가 배치에서 선택되었는지 확인합니다.
    public func isBatchSensorSelected(_ sensor: SensorType) -> Bool {
        return batchDataConfigurationManager.isSensorSelected(sensor)
    }
    
    /// 배치 가속도계 모드를 업데이트합니다.
    public func updateBatchAccelerometerMode(_ mode: AccelerometerMode) {
        batchDataConfigurationManager.updateAccelerometerMode(mode)
    }
    
    // MARK: - Sensor Data Parsing
    
    /// EEG 원시 데이터를 구조화된 읽기값으로 파싱합니다.
    ///
    /// - Parameter data: EEG 특성에서 수신된 원시 바이너리 데이터
    /// - Returns: 패킷에서 추출된 EEG 읽기값 배열
    /// - Throws: 패킷 형식이 유효하지 않은 경우 `BluetoothKitError.dataParsingFailed`
    ///
    /// ## 예시
    /// ```swift
    /// do {
    ///     let eegReadings = try bluetoothKit.parseEEGData(rawData)
    ///     for reading in eegReadings {
    ///         print("CH1: \(reading.channel1) μV, CH2: \(reading.channel2) μV")
    ///     }
    /// } catch {
    ///     print("EEG 데이터 파싱 실패: \(error)")
    /// }
    /// ```
    public func parseEEGData(_ data: Data) throws -> [EEGReading] {
        return try sensorDataParser.parseEEGData(data)
    }
    
    /// PPG 원시 데이터를 구조화된 읽기값으로 파싱합니다.
    ///
    /// - Parameter data: PPG 특성에서 수신된 원시 바이너리 데이터
    /// - Returns: 패킷에서 추출된 PPG 읽기값 배열
    /// - Throws: 패킷 형식이 유효하지 않은 경우 `BluetoothKitError.dataParsingFailed`
    ///
    /// ## 예시
    /// ```swift
    /// do {
    ///     let ppgReadings = try bluetoothKit.parsePPGData(rawData)
    ///     for reading in ppgReadings {
    ///         print("Red: \(reading.red), IR: \(reading.ir)")
    ///     }
    /// } catch {
    ///     print("PPG 데이터 파싱 실패: \(error)")
    /// }
    /// ```
    public func parsePPGData(_ data: Data) throws -> [PPGReading] {
        return try sensorDataParser.parsePPGData(data)
    }
    
    /// 가속도계 원시 데이터를 구조화된 읽기값으로 파싱합니다.
    ///
    /// - Parameter data: 가속도계 특성에서 수신된 원시 바이너리 데이터
    /// - Returns: 패킷에서 추출된 가속도계 읽기값 배열
    /// - Throws: 패킷 형식이 유효하지 않은 경우 `BluetoothKitError.dataParsingFailed`
    ///
    /// ## 예시
    /// ```swift
    /// do {
    ///     let accelReadings = try bluetoothKit.parseAccelerometerData(rawData)
    ///     for reading in accelReadings {
    ///         print("X: \(reading.x), Y: \(reading.y), Z: \(reading.z)")
    ///     }
    /// } catch {
    ///     print("가속도계 데이터 파싱 실패: \(error)")
    /// }
    /// ```
    public func parseAccelerometerData(_ data: Data) throws -> [AccelerometerReading] {
        return try sensorDataParser.parseAccelerometerData(data)
    }
    
    /// 배터리 원시 데이터를 구조화된 읽기값으로 파싱합니다.
    ///
    /// - Parameter data: 배터리 특성에서 수신된 원시 바이너리 데이터
    /// - Returns: 현재 배터리 레벨을 포함한 배터리 읽기값
    /// - Throws: 데이터가 유효하지 않은 경우 `BluetoothKitError.dataParsingFailed`
    ///
    /// ## 예시
    /// ```swift
    /// do {
    ///     let batteryReading = try bluetoothKit.parseBatteryData(rawData)
    ///     print("배터리 레벨: \(batteryReading.level)%")
    /// } catch {
    ///     print("배터리 데이터 파싱 실패: \(error)")
    /// }
    /// ```
    public func parseBatteryData(_ data: Data) throws -> BatteryReading {
        return try sensorDataParser.parseBatteryData(data)
    }
}

// MARK: - BluetoothManagerDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: BluetoothManagerDelegate {
    
    internal func bluetoothManager(_ manager: AnyObject, didUpdateState state: ConnectionState) {
        connectionState = state
        connectionStatusDescription = state.description
        isScanning = bluetoothManager.isScanning
        
        if case .failed(let error) = state,
           error.localizedDescription.contains("Bluetooth is not available") {
            isBluetoothDisabled = true
        } else {
            isBluetoothDisabled = false
        }
    }
    
    internal func bluetoothManager(_ manager: AnyObject, didDiscoverDevice device: BluetoothDevice) {
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == device.peripheral.identifier }) {
            discoveredDevices.append(device)
            delegate?.bluetoothKit(self, didDiscoverDevice: device)
        }
    }
    
    internal func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice) {
        // 연결 성공 로그 제거
    }
    
    internal func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?) {
        if let error = error {
            log("Disconnected from \(device.name) with error: \(error.localizedDescription)")
        }
        // 정상 연결 해제는 로그하지 않음
    }
}

// MARK: - SensorDataDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: SensorDataDelegate {
    
    internal func didReceiveEEGData(_ reading: EEGReading) {
        // 선택된 센서가 아니면 처리하지 않음
        guard selectedSensors.contains(.eeg) else { return }
        
        latestEEGReading = reading
        
        // 기록 중이면 모든 선택된 센서 데이터를 기록
        if isRecording {
            dataRecorder.recordEEGData([reading])
        }
        
        addToEEGBuffer(reading)
    }
    
    internal func didReceivePPGData(_ reading: PPGReading) {
        // 선택된 센서가 아니면 처리하지 않음
        guard selectedSensors.contains(.ppg) else { return }
        
        latestPPGReading = reading
        
        // 기록 중이면 모든 선택된 센서 데이터를 기록
        if isRecording {
            dataRecorder.recordPPGData([reading])
        }
        
        addToPPGBuffer(reading)
    }
    
    internal func didReceiveAccelerometerData(_ reading: AccelerometerReading) {
        // 선택된 센서가 아니면 처리하지 않음
        guard selectedSensors.contains(.accelerometer) else { return }
        
        // 가속도계 모드에 따라 데이터 처리 (원시값 또는 선형 가속도)
        let processedReading = processAccelerometerReading(reading)
        
        // 처리된 데이터를 최신 읽기값으로 저장
        latestAccelerometerReading = processedReading
        
        // 기록 중이면 모든 선택된 센서 데이터를 기록
        if isRecording {
            dataRecorder.recordAccelerometerData([processedReading])
        }
        
        // 배치 처리에도 처리된 데이터 사용
        addToAccelerometerBuffer(processedReading)
    }
    
    internal func didReceiveBatteryData(_ reading: BatteryReading) {
        // 배터리 데이터는 항상 처리 (예외)
        latestBatteryReading = reading
        
        // 배터리 데이터도 기록 (배치 수집 설정과 무관하게)
        if isRecording {
            dataRecorder.recordBatteryData(reading)
        }
    }
}

// MARK: - DataRecorderDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: DataRecorderDelegate {
    
    public func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date) {
        isRecording = true
        log("Started recording at: \(at)")
    }
    
    public func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL]) {
        isRecording = false
        updateRecordedFiles()
        log("Stopped recording at: \(at), saved \(savedFiles.count) files")
    }
    
    public func dataRecorder(_ recorder: AnyObject, didFailWithError error: Error) {
        log("Recording error: \(error.localizedDescription)")
    }
}

// MARK: - Internal Helper Methods

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit {
    // Duplicate functions removed - they are already defined earlier in the file
}

// MARK: - BatchDataConfigurationManagerDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: BatchDataConfigurationManagerDelegate {
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateCollectionMode mode: BatchDataConfigurationManager.CollectionMode) {
        // 내부적으로 처리, 외부 delegate에는 필요시 전달
    }
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateSelectedSensors sensors: Set<SensorType>) {
        // 내부적으로 처리, 외부 delegate에는 필요시 전달
    }
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateMonitoringState isActive: Bool) {
        // BluetoothKitDelegate에게 배치 모니터링 상태 변화 알림
        delegate?.bluetoothKit(self, didUpdateBatchMonitoringState: isActive)
    }
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateShowRecordingChangeWarning show: Bool) {
        // 내부적으로 처리, 외부 delegate에는 필요시 전달
    }
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingSensorSelection sensors: Set<SensorType>?) {
        // 내부적으로 처리, 외부 delegate에는 필요시 전달
    }
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdatePendingConfigurationChange change: BatchDataConfigurationManager.PendingConfigurationChange?) {
        // 내부적으로 처리, 외부 delegate에는 필요시 전달
    }
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, didUpdateSensorConfigurations configurations: [SensorType: BatchDataConfigurationManager.SensorConfiguration]) {
        // 내부적으로 처리, 외부 delegate에는 필요시 전달
    }
    
    internal func batchDataConfigurationManager(_ manager: BatchDataConfigurationManager, needsUpdateRecordingSensors sensors: Set<SensorType>) {
        // 기록 중 센서 업데이트 요청을 받아서 실제 updateRecordingSensors 호출
        updateRecordingSensors(sensors)
    }
} 