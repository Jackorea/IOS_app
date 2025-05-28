import Foundation
import SwiftUI
import CoreBluetooth

// PPG 관련 전역 변수 및 타입 정의
private var PPG_SAMPLE_RATE: Double = 50.0
private var EEG_SAMPLE_RATE: Double = 250.0
private var ACC_SAMPLE_RATE: Double = 50.0  // 파이썬과 동일한 가속도계 샘플링 레이트

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
    @Published public var rawDataJSONString: String = "{}"
    
    private var lastConnectedPeripheralIdentifier: UUID?
    private var userInitiatedDisconnect: Bool = false
    private var eegCsvWriter: TextOutputStream?
    private var ppgCsvWriter: TextOutputStream?
    private var accelCsvWriter: TextOutputStream?
    private var rawDataWriter: TextOutputStream?
    
    // Raw 데이터를 저장하기 위한 구조체들 (JSON 직접 구성으로 변경되므로 RawDataPacket 등은 사용 안 함)
    // private struct RawPPGData: Codable { ... }
    // private struct RawEEGData: Codable { ... }
    // private struct RawAccelData: Codable { ... }
    // private struct RawDataPacket: Codable { ... }
    
    // private var rawDataArray: [RawDataPacket] = [] // 기존 배열 주석 처리 또는 삭제
    // 요청된 JSON 구조를 위한 딕셔너리
    private var rawDataDict: [String: Any] = [ // 각 키의 값은 특정 타입의 배열임
        "timestamp": [Double](),
        "eegChannel1": [Double](),
        "eegChannel2": [Double](),
        "eegLeadOff": [Int](), // 0 for false, 1 for true
        "ppgRed": [Int](),
        "ppgIr": [Int](),
        "accelX": [Int](),
        "accelY": [Int](),
        "accelZ": [Int]()
    ]
    
    // 1초 간격 타임스탬프 저장을 위한 타이머
    private var recordingTimer: Timer?
    
    // 저장된 파일들의 디렉토리 URL을 반환
    public var recordingsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // JSON 파일 저장을 위한 Encodable 구조체
    private struct SensorDataJSON: Encodable {
        let timestamp: [Double]
        let eegChannel1: [Double]
        let eegChannel2: [Double]
        let eegLeadOff: [Int]
        let ppgRed: [Int]
        let ppgIr: [Int]
        let accelX: [Int]
        let accelY: [Int]
        let accelZ: [Int]
    }
    
    override public init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
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
        print("startRecording called") // DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestampString = dateFormatter.string(from: Date())
        
        let rawDataURL = recordingsDirectory.appendingPathComponent("raw_data_\(timestampString).json")
        FileManager.default.createFile(atPath: rawDataURL.path, contents: nil, attributes: nil)
        if let handle = try? FileHandle(forWritingTo: rawDataURL) {
            rawDataWriter = FileWriter(fileHandle: handle)
            rawDataDict = [
                "timestamp": [Double](),
                "eegChannel1": [Double](),
                "eegChannel2": [Double](),
                "eegLeadOff": [Int](),
                "ppgRed": [Int](),
                "ppgIr": [Int](),
                "accelX": [Int](),
                "accelY": [Int](),
                "accelZ": [Int]()
            ]
        }
        
        // CSV 파일명 타임스탬프 (기존 로직 유지)
        let csvTimestampString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        // EEG CSV 파일 생성
        let eegCsvURL = recordingsDirectory.appendingPathComponent("eeg_data_\(csvTimestampString).csv")
        FileManager.default.createFile(atPath: eegCsvURL.path, contents: nil, attributes: nil)
        if let handle = try? FileHandle(forWritingTo: eegCsvURL) {
            var writer = FileWriter(fileHandle: handle)
            writer.write("timestamp,ch1Raw,ch2Raw,ch1uV,ch2uV,leadOffNormalized\n")
            eegCsvWriter = writer
        }
        
        // PPG CSV 파일 생성
        let ppgCsvURL = recordingsDirectory.appendingPathComponent("ppg_data_\(csvTimestampString).csv")
        FileManager.default.createFile(atPath: ppgCsvURL.path, contents: nil, attributes: nil)
        if let handle = try? FileHandle(forWritingTo: ppgCsvURL) {
            var writer = FileWriter(fileHandle: handle)
            writer.write("timestamp,PPG_red,PPG_ir\n")
            ppgCsvWriter = writer
        }
        
        // ACC CSV 파일 생성
        let accelCsvURL = recordingsDirectory.appendingPathComponent("accel_data_\(csvTimestampString).csv")
        FileManager.default.createFile(atPath: accelCsvURL.path, contents: nil, attributes: nil)
        if let handle = try? FileHandle(forWritingTo: accelCsvURL) {
            var writer = FileWriter(fileHandle: handle)
            writer.write("timestamp,ACCEL_x,ACCEL_y,ACCEL_z\n")
            accelCsvWriter = writer
        }
        
        isRecording = true
        // 1초 간격 타이머 시작
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            let currentTime = Date().timeIntervalSince1970 * 1000 // 밀리세컨드 단위로 저장
            if var tsArray = self.rawDataDict["timestamp"] as? [Double] {
                tsArray.append(currentTime)
                self.rawDataDict["timestamp"] = tsArray
            } else {
                // print("Error: Could not append to timestamp array in rawDataDict") // DEBUG
            }
             // print("Timer ticked: \(currentTime)") // DEBUG
        }
        print("Recording started, JSON will be saved to: \(rawDataURL.path)")
        print("EEG CSV: eeg_data_\(csvTimestampString).csv")
        print("PPG CSV: ppg_data_\(csvTimestampString).csv") 
        print("ACC CSV: accel_data_\(csvTimestampString).csv")
        rawDataJSONString = "{}"
    }
    
    public func stopRecording() {
        print("stopRecording called") // DEBUG
        isRecording = false
        recordingTimer?.invalidate() // 타이머 중지
        recordingTimer = nil
        
        // JSON 파일 저장
        if let handle = (rawDataWriter as? FileWriter)?.fileHandle {
            // rawDataDict를 SensorDataJSON 구조체로 변환
            let encodableData = SensorDataJSON(
                timestamp: rawDataDict["timestamp"] as? [Double] ?? [],
                eegChannel1: rawDataDict["eegChannel1"] as? [Double] ?? [],
                eegChannel2: rawDataDict["eegChannel2"] as? [Double] ?? [],
                eegLeadOff: rawDataDict["eegLeadOff"] as? [Int] ?? [],
                ppgRed: rawDataDict["ppgRed"] as? [Int] ?? [],
                ppgIr: rawDataDict["ppgIr"] as? [Int] ?? [],
                accelX: rawDataDict["accelX"] as? [Int] ?? [],
                accelY: rawDataDict["accelY"] as? [Int] ?? [],
                accelZ: rawDataDict["accelZ"] as? [Int] ?? []
            )
            
            do {
                let jsonData = try JSONEncoder().encode(encodableData) // 이제 SensorDataJSON 인스턴스를 인코딩
                handle.seek(toFileOffset: 0)
                handle.write(jsonData)
                print("Raw data JSON saved.")
            } catch {
                print("Error saving raw data JSON: \(error)")
            }
            try? handle.close()
        }
        rawDataWriter = nil
        // 저장 후 rawDataDict 초기화
        rawDataDict = [
            "timestamp": [Double](),
            "eegChannel1": [Double](),
            "eegChannel2": [Double](),
            "eegLeadOff": [Int](),
            "ppgRed": [Int](),
            "ppgIr": [Int](),
            "accelX": [Int](),
            "accelY": [Int](),
            "accelZ": [Int]()
        ]
        rawDataJSONString = "{}"
        
        // 개별 CSV 파일들 닫기
        if let handle = (eegCsvWriter as? FileWriter)?.fileHandle {
            try? handle.close()
        }
        eegCsvWriter = nil
        
        if let handle = (ppgCsvWriter as? FileWriter)?.fileHandle {
            try? handle.close()
        }
        ppgCsvWriter = nil
        
        if let handle = (accelCsvWriter as? FileWriter)?.fileHandle {
            try? handle.close()
        }
        accelCsvWriter = nil
        
        updateRecordedFiles()
        print("Recording stopped.")
    }
    
    private func updateRawDataJSONString() {
        // rawDataDict를 SensorDataJSON 구조체로 변환
        let encodableData = SensorDataJSON(
            timestamp: rawDataDict["timestamp"] as? [Double] ?? [],
            eegChannel1: rawDataDict["eegChannel1"] as? [Double] ?? [],
            eegChannel2: rawDataDict["eegChannel2"] as? [Double] ?? [],
            eegLeadOff: rawDataDict["eegLeadOff"] as? [Int] ?? [],
            ppgRed: rawDataDict["ppgRed"] as? [Int] ?? [],
            ppgIr: rawDataDict["ppgIr"] as? [Int] ?? [],
            accelX: rawDataDict["accelX"] as? [Int] ?? [],
            accelY: rawDataDict["accelY"] as? [Int] ?? [],
            accelZ: rawDataDict["accelZ"] as? [Int] ?? []
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(encodableData), let jsonString = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.rawDataJSONString = jsonString
            }
        }
    }
    
    public func handlePPGData(_ data: Data) {
        print("handlePPGData called, data count: \(data.count)")
        let bytes = [UInt8](data)
        guard bytes.count == 172 else {
            print("PPG packet length invalid: \(bytes.count) bytes (expected 172).")
            return
        }

        for i in stride(from: 4, to: 172, by: 6) {
            let red = Int(bytes[i]) << 16 | Int(bytes[i+1]) << 8 | Int(bytes[i+2])
            let ir  = Int(bytes[i+3]) << 16 | Int(bytes[i+4]) << 8 | Int(bytes[i+5])
            let csvTimestamp = Date().timeIntervalSince1970 // CSV용 타임스탬프
            
            // 녹화 상태와 관계없이 터미널에 샘플 값 출력 (Live View)
            print("[PPG Sample (Live)] Red: \(red), IR: \(ir)")

            if isRecording {
                if var ppgRedArray = rawDataDict["ppgRed"] as? [Int] {
                    ppgRedArray.append(red)
                    rawDataDict["ppgRed"] = ppgRedArray
                }
                if var ppgIrArray = rawDataDict["ppgIr"] as? [Int] {
                    ppgIrArray.append(ir)
                    rawDataDict["ppgIr"] = ppgIrArray
                }
                
                // PPG CSV에 기록
                if var writer = ppgCsvWriter {
                    // timestamp,PPG_red,PPG_ir
                    let line = "\(csvTimestamp),\(red),\(ir)\n"
                    writer.write(line)
                }
            }
            
            DispatchQueue.main.async {
                self.lastPPGReading = (red: red, ir: ir)
            }
        }
        if isRecording { updateRawDataJSONString() } // 패킷 처리 후 JSON 문자열 UI 업데이트
    }

    public func handleEEGData(_ data: Data) {
        print("handleEEGData called, data count: \(data.count)")
        let bytes = [UInt8](data)
        
        // Python과 동일: 179바이트 고정 (4바이트 헤더 + 25개 샘플 * 7바이트)
        guard bytes.count == 179 else {
            print("EEG packet length invalid: \(bytes.count) bytes (expected 179).")
            return
        }
        
        // Python과 동일: 패킷 헤더에서 타임스탬프 추출
        let timeRaw = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
        var timestamp = Double(timeRaw) / 32.768 / 1000.0 // ms 단위를 sec 단위로
        
        // Python과 동일: 4바이트부터 179바이트까지 7바이트씩 처리 (25개 샘플)
        for i in stride(from: 4, to: 179, by: 7) {
            // lead-off (1바이트) - 센서 연결 상태 정규화
            let leadOffRaw = bytes[i]
            let leadOffNormalized = leadOffRaw > 0 ? 1 : 0  // 하나라도 떨어져 있으면 1, 모두 정상이면 0
            
            // CH1: 3 bytes (Big Endian)
            var ch1Raw = Int32(bytes[i+1]) << 16 | Int32(bytes[i+2]) << 8 | Int32(bytes[i+3])
            
            // CH2: 3 bytes (Big Endian)  
            var ch2Raw = Int32(bytes[i+4]) << 16 | Int32(bytes[i+5]) << 8 | Int32(bytes[i+6])
            
            // Python과 동일: 24bit signed 처리 (MSB 기준 음수 보정)
            if (ch1Raw & 0x800000) != 0 {
                ch1Raw -= 0x1000000
            }
            if (ch2Raw & 0x800000) != 0 {
                ch2Raw -= 0x1000000
            }
            
            // Python과 동일: 전압값(uV)로 변환
            let ch1uV = Double(ch1Raw) * 4.033 / 12.0 / Double(0x7FFFFF) * 1e6
            let ch2uV = Double(ch2Raw) * 4.033 / 12.0 / Double(0x7FFFFF) * 1e6
            
            // 녹화 상태와 관계없이 터미널에 샘플 값 출력 (Live View) - 개선된 출력
            let connectionStatus = leadOffNormalized == 0 ? "✅ Connected" : "⚠️ Disconnected"
            print("[EEG Sample (Live)] CH1_raw: \(ch1Raw), CH2_raw: \(ch2Raw), CH1: \(ch1uV) µV, CH2: \(ch2uV) µV, LeadOff: \(leadOffNormalized) (\(connectionStatus))")
            
            if isRecording {
                if var eegCh1Array = rawDataDict["eegChannel1"] as? [Double] {
                    eegCh1Array.append(ch1uV)
                    rawDataDict["eegChannel1"] = eegCh1Array
                }
                if var eegCh2Array = rawDataDict["eegChannel2"] as? [Double] {
                    eegCh2Array.append(ch2uV)
                    rawDataDict["eegChannel2"] = eegCh2Array
                }
                if var eegLeadOffArray = rawDataDict["eegLeadOff"] as? [Int] {
                    eegLeadOffArray.append(leadOffNormalized)  // 정규화된 값 저장
                    rawDataDict["eegLeadOff"] = eegLeadOffArray
                }
                
                // EEG CSV에 기록 (헤더 순서와 일치하도록 수정)
                if var writer = eegCsvWriter {
                    let line = "\(timestamp),\(ch1Raw),\(ch2Raw),\(ch1uV),\(ch2uV),\(leadOffNormalized)\n"
                    writer.write(line)
                }
                
                // Python과 동일: 다음 샘플 타임스탬프 증가 (EEG_SAMPLE_RATE 가정: 250Hz)
                timestamp += 1.0 / EEG_SAMPLE_RATE
            }
            
            // UI 업데이트는 마지막 샘플에서만 (성능 최적화)
            if i == 172 { // 마지막 샘플 (4 + 24*7 = 172)
                DispatchQueue.main.async {
                    // UI에서는 Boolean 변환 사용
                    self.lastEEGReading = (ch1: ch1uV, ch2: ch2uV, leadOff: leadOffNormalized == 1)
                }
            }
        }
        if isRecording { updateRawDataJSONString() } // 패킷 처리 후 JSON 문자열 UI 업데이트
    }

    public func handleAccelData(_ data: Data) {
        print("handleAccelData called, data count: \(data.count)")
        let bytes = [UInt8](data)
        let headerSize = 4
        let sampleSize = 6
        
        guard bytes.count >= headerSize + sampleSize else { 
            print("ACCEL packet too short (even for header + 1 sample): \(bytes.count) bytes. Expected at least \(headerSize + sampleSize) bytes.")
            return
        }
        
        // 파이썬과 동일: 패킷 헤더에서 타임스탬프 추출
        let timeRaw = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16 | UInt32(bytes[1]) << 8 | UInt32(bytes[0])
        var timestamp = Double(timeRaw) / 32.768 / 1000.0 // ms 단위를 sec 단위로

        let dataWithoutHeaderCount = bytes.count - headerSize
        guard dataWithoutHeaderCount >= sampleSize else {
            print("ACCEL packet has header but not enough data for one sample: \(bytes.count) bytes.")
            return
        }
        
        let sampleCount = dataWithoutHeaderCount / sampleSize

        for i in 0..<sampleCount {
            let baseInFullPacket = headerSize + (i * sampleSize)
            // 파이썬과 동일: 홀수 번째 바이트만 사용 (1, 3, 5번째)
            let x = Int(bytes[baseInFullPacket + 1])  // data[i+1]
            let y = Int(bytes[baseInFullPacket + 3])  // data[i+3] 
            let z = Int(bytes[baseInFullPacket + 5])  // data[i+5]
            
            // 녹화 상태와 관계없이 터미널에 샘플 값 출력 (Live View)
            print("[ACCEL Sample (Live)] X: \(x), Y: \(y), Z: \(z)")

            if isRecording {
                if var accelXArray = rawDataDict["accelX"] as? [Int] {
                    accelXArray.append(x)
                    rawDataDict["accelX"] = accelXArray
                }
                if var accelYArray = rawDataDict["accelY"] as? [Int] {
                    accelYArray.append(y)
                    rawDataDict["accelY"] = accelYArray
                }
                if var accelZArray = rawDataDict["accelZ"] as? [Int] {
                    accelZArray.append(z)
                    rawDataDict["accelZ"] = accelZArray
                }
                
                // ACC CSV에 기록 (파이썬과 동일한 타임스탬프 사용)
                if var writer = accelCsvWriter {
                    // timestamp,ACCEL_x,ACCEL_y,ACCEL_z
                    let line = "\(timestamp),\(x),\(y),\(z)\n"
                    writer.write(line)
                }
                
                // 파이썬과 동일: 다음 샘플 타임스탬프 증가 (ACC_SAMPLE_RATE 가정)
                timestamp += 1.0 / ACC_SAMPLE_RATE
            }

             if i == sampleCount - 1 {
                DispatchQueue.main.async {
                    self.lastAccelReading = (x: Int16(x), y: Int16(y), z: Int16(z))
                }
            }
        }
        if isRecording { updateRawDataJSONString() } // 패킷 처리 후 JSON 문자열 UI 업데이트
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
