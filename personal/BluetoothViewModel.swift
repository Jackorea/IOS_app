import Foundation
import SwiftUI
import CoreBluetooth

// PPG 관련 전역 변수 및 타입 정의
private var PPG_SAMPLE_RATE: Double = 50.0

fileprivate struct FileWriter: TextOutputStream {
    let fileHandle: FileHandle
    mutating func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

public class BluetoothViewModel: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    @Published public var devices: [BluetoothDevice] = []
    @Published public var isScanning = false
    @Published public var connectedPeripheral: CBPeripheral? = nil
    @Published public var showBluetoothOffAlert = false
    @Published public var connectionStatus: String = "Not Connected"
    @Published public var autoReconnectEnabled: Bool = true // 오토커넥션 여부
    
    // PPG 관련 프로퍼티
    @Published public var isRecording: Bool = false
    @Published public var lastPPGReading: (red: Int, ir: Int) = (0, 0)
    @Published public var lastEEGReading: (ch1: Double, ch2: Double, leadOff: Bool) = (0, 0, false)
    @Published public var lastAccelReading: (x: Int16, y: Int16, z: Int16) = (0, 0, 0)
    @Published public var recordedFiles: [URL] = []
    
    private var lastConnectedPeripheralIdentifier: UUID? // 마지막 연결된 기기 ID
    private var userInitiatedDisconnect: Bool = false // 사용자에 의한 연결 해제 여부
    private var ppgWriter: TextOutputStream?
    private var eegWriter: TextOutputStream?
    private var accelWriter: TextOutputStream?
    private var lastRecordedTimestamp: TimeInterval = 0
    private var currentSensorData: SensorData
    
    // 센서 데이터를 임시 저장하는 구조체
    private struct SensorData {
        var timestamp: TimeInterval = 0
        var ppg: (red: Int, ir: Int) = (0, 0)
        var eeg: (ch1: Double, ch2: Double, leadOff: Bool) = (0, 0, false)
        var accel: (x: Int16, y: Int16, z: Int16) = (0, 0, 0)
        var isUpdated: (ppg: Bool, eeg: Bool, accel: Bool) = (false, false, false)
        
        mutating func reset() {
            isUpdated = (false, false, false)
        }
        
        var allUpdated: Bool {
            return isUpdated.ppg && isUpdated.eeg && isUpdated.accel
        }
        
        func toCsvString() -> String {
            return "\(timestamp),\(ppg.red),\(ppg.ir),\(eeg.ch1),\(eeg.ch2),\(eeg.leadOff ? 1 : 0),\(accel.x),\(accel.y),\(accel.z)\n"
        }
    }
    
    // 저장된 파일들의 디렉토리 URL을 반환
    public var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]  // 루트 Documents 디렉토리 반환
    }
    
    override public init() {
        currentSensorData = SensorData()
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        // 초기화 시 저장된 파일 목록 로드
        updateRecordedFiles()
    }
    
    // 저장된 파일 목록 업데이트
    private func updateRecordedFiles() {
        recordedFiles = (try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
    }
    
    // 데이터 기록 시작
    public func startRecording() {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        
        // EEG 파일 생성
        let eegFileURL = recordingsDirectory.appendingPathComponent("eeg_\(timestamp).csv")
        FileManager.default.createFile(atPath: eegFileURL.path, contents: nil, attributes: nil)
        if let handle = try? FileHandle(forWritingTo: eegFileURL) {
            var writer = FileWriter(fileHandle: handle)
            writer.write("timestamp,lead_off,ch1_uV,ch2_uV\n")
            eegWriter = writer
        }
        
        // PPG 파일 생성
        let ppgFileURL = recordingsDirectory.appendingPathComponent("ppg_\(timestamp).csv")
        FileManager.default.createFile(atPath: ppgFileURL.path, contents: nil, attributes: nil)
        if let handle = try? FileHandle(forWritingTo: ppgFileURL) {
            var writer = FileWriter(fileHandle: handle)
            writer.write("timestamp,ppg_red,ppg_ir\n")
            ppgWriter = writer
        }
        
        // ACC 파일 생성
        let accFileURL = recordingsDirectory.appendingPathComponent("acc_\(timestamp).csv")
        FileManager.default.createFile(atPath: accFileURL.path, contents: nil, attributes: nil)
        if let handle = try? FileHandle(forWritingTo: accFileURL) {
            var writer = FileWriter(fileHandle: handle)
            writer.write("timestamp,acc_x,acc_y,acc_z\n")
            accelWriter = writer
        }
        
        isRecording = true
        currentSensorData = SensorData()
        lastRecordedTimestamp = Date().timeIntervalSince1970
        print("Recording started")
    }
    
    public func stopRecording() {
        isRecording = false
        
        // EEG 파일 닫기
        if let handle = (eegWriter as? FileWriter)?.fileHandle {
            try? handle.close()
        }
        eegWriter = nil
        
        // PPG 파일 닫기
        if let handle = (ppgWriter as? FileWriter)?.fileHandle {
            try? handle.close()
        }
        ppgWriter = nil
        
        // ACC 파일 닫기
        if let handle = (accelWriter as? FileWriter)?.fileHandle {
            try? handle.close()
        }
        accelWriter = nil
        
        updateRecordedFiles()
        print("Recording stopped.")
    }
    
    // 센서 데이터 업데이트 및 저장
    private func updateAndSaveData() {
        guard isRecording, var writer = ppgWriter else { return }
        
        let currentTime = Date().timeIntervalSince1970
        // 모든 센서 데이터가 업데이트되었거나, 마지막 저장 후 일정 시간이 지났을 때 저장
        if currentSensorData.allUpdated || (currentTime - lastRecordedTimestamp) >= 0.02 { // 50Hz로 제한
            writer.write("\(currentTime),\(currentSensorData.ppg.red),\(currentSensorData.ppg.ir)\n")
            lastRecordedTimestamp = currentTime
            currentSensorData.reset()
        }
    }
    
    public func handlePPGData(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count == 172 else {
            print("PPG packet length invalid: \(bytes.count) bytes (expected 172).")
            return
        }

        // 타임스탬프 계산
        let timeRaw = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
        var timestamp = Double(timeRaw) / 32.768 / 1000.0

        // RED/IR 데이터 샘플 분해
        for i in stride(from: 4, to: 172, by: 6) {
            let red = Int(bytes[i]) << 16 | Int(bytes[i+1]) << 8 | Int(bytes[i+2])
            let ir  = Int(bytes[i+3]) << 16 | Int(bytes[i+4]) << 8 | Int(bytes[i+5])

            // UI 업데이트
            DispatchQueue.main.async {
                self.lastPPGReading = (red: red, ir: ir)
            }

            if isRecording, var writer = ppgWriter {
                let currentTime = Date().timeIntervalSince1970
                writer.write("\(currentTime),\(red),\(ir)\n")
            }

            timestamp += 1.0 / PPG_SAMPLE_RATE
        }

        print("Last sample - RED: \(lastPPGReading.red), IR: \(lastPPGReading.ir)")
    }

    public func handleEEGData(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 5 else { return }

        let ch1 = Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let ch2 = Int16(bitPattern: UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
        let leadOff = bytes[4] != 0

        let ch1uV = Double(ch1) * 0.195
        let ch2uV = Double(ch2) * 0.195

        // UI 업데이트
        DispatchQueue.main.async {
            self.lastEEGReading = (ch1: ch1uV, ch2: ch2uV, leadOff: leadOff)
        }

        if isRecording, var writer = eegWriter {
            let timestamp = Date().timeIntervalSince1970
            writer.write("\(timestamp),\(leadOff ? 1 : 0),\(ch1uV),\(ch2uV)\n")
        }

        print("EEG CH1: \(ch1uV) µV, CH2: \(ch2uV) µV, LeadOff: \(leadOff)")
    }

    public func handleAccelData(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 6 else { return }

        let x = Int16(bitPattern: UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let y = Int16(bitPattern: UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
        let z = Int16(bitPattern: UInt16(bytes[4]) | (UInt16(bytes[5]) << 8))

        // UI 업데이트
        DispatchQueue.main.async {
            self.lastAccelReading = (x: x, y: y, z: z)
        }

        if isRecording, var writer = accelWriter {
            let timestamp = Date().timeIntervalSince1970
            writer.write("\(timestamp),\(x),\(y),\(z)\n")
        }

        print("Accel X: \(x), Y: \(y), Z: \(z)")
    }

    public func handleBatteryData(_ data: Data) {
        guard let level = data.first else { return }
        print("Battery: \(level)%")
        // TODO: UI에 표시
    }


    public func startScan() {
        guard centralManager.state == .poweredOn else {
            isScanning = false
            showBluetoothOffAlert = true
            return
        }
        centralManager.stopScan()
        devices.removeAll()
        centralManager.scanForPeripherals(withServices: nil)
        isScanning = true
    }

    public func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    public func connectToDevice(_ device: BluetoothDevice) {
        centralManager.connect(device.peripheral, options: nil)
        connectionStatus = "Connecting to \(device.name)..."
    }
    
    public func disconnect() {
        guard let connected = connectedPeripheral else { return }
        // 연결 해제 시 녹화 중지
        if isRecording {
            stopRecording()
        }
        userInitiatedDisconnect = true // 사용자가 연결 해제 시도
        centralManager.cancelPeripheralConnection(connected)
        connectionStatus = "Disconnecting..."
    }
}


extension BluetoothViewModel: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            isScanning = false
        default:
            isScanning = false
        }
    }

    public func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? ""
        guard name.hasPrefix("LXB-") else { return }

        if !devices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = BluetoothDevice(peripheral: peripheral, name: name)
            devices.append(device)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectionStatus = "Connected to \(peripheral.name ?? "Device")"
        print("✅ Connected to \(peripheral.name ?? "unknown device")")
        stopScan() // 스캔 중지
        lastConnectedPeripheralIdentifier = peripheral.identifier // 마지막 연결 기기 ID 저장
        userInitiatedDisconnect = false // 연결 성공 시 플래그 리셋
        
        // ✅ 연결 후 서비스 검색 시작
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "❌ Failed to connect"
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Disconnected"
        let disconnectedPeripheralName = peripheral.name ?? "device"
        print("Bluetooth device \(disconnectedPeripheralName) disconnected with error: \(error?.localizedDescription ?? "None")")

        // 연결 해제 시 녹화 중지
        if isRecording {
            stopRecording()
        }

        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }

        // 오토커넥션 로직
        if !userInitiatedDisconnect && autoReconnectEnabled,
           let lastID = lastConnectedPeripheralIdentifier,
           peripheral.identifier == lastID {
            print("Attempting to auto-reconnect to \(disconnectedPeripheralName)...")
            connectionStatus = "Reconnecting to \(disconnectedPeripheralName)..."
            centralManager.connect(peripheral, options: nil)
        } else if userInitiatedDisconnect {
            // 사용자에 의한 연결 해제였으면 플래그 리셋
            lastConnectedPeripheralIdentifier = nil 
            userInitiatedDisconnect = false
            print("User initiated disconnect. Auto-reconnect will not be attempted for \(disconnectedPeripheralName).")
        }
    }
}


extension BluetoothViewModel: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case SensorUUID.eegNotifyChar,
                 SensorUUID.ppgChar,
                 SensorUUID.accelChar,
                 SensorUUID.batteryChar:
                peripheral.setNotifyValue(true, for: characteristic)
                print("🔔 Notify enabled for: \(characteristic.uuid)")

            default:
                break
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case SensorUUID.eegNotifyChar:
            handleEEGData(data)
        case SensorUUID.ppgChar:
            handlePPGData(data)
        case SensorUUID.accelChar:
            handleAccelData(data)
        case SensorUUID.batteryChar:
            handleBatteryData(data)
        default:
            break
        }
    }
} 
