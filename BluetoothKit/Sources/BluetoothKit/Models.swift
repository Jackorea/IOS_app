import Foundation
import CoreBluetooth

// MARK: - Device Models

public struct BluetoothDevice: Identifiable, Equatable, @unchecked Sendable {
    public let id: UUID = UUID()
    public let peripheral: CBPeripheral
    public let name: String
    public let rssi: NSNumber?
    
    public init(peripheral: CBPeripheral, name: String, rssi: NSNumber? = nil) {
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
    }
    
    public static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        return lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}

// MARK: - Sensor Data Models

public struct EEGReading: Sendable {
    public let channel1: Double  // µV
    public let channel2: Double  // µV
    public let leadOff: Bool
    public let timestamp: Date
    
    public init(channel1: Double, channel2: Double, leadOff: Bool, timestamp: Date = Date()) {
        self.channel1 = channel1
        self.channel2 = channel2
        self.leadOff = leadOff
        self.timestamp = timestamp
    }
}

public struct PPGReading: Sendable {
    public let red: Int
    public let ir: Int
    public let timestamp: Date
    
    public init(red: Int, ir: Int, timestamp: Date = Date()) {
        self.red = red
        self.ir = ir
        self.timestamp = timestamp
    }
}

public struct AccelerometerReading: Sendable {
    public let x: Int16
    public let y: Int16
    public let z: Int16
    public let timestamp: Date
    
    public init(x: Int16, y: Int16, z: Int16, timestamp: Date = Date()) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }
}

public struct BatteryReading: Sendable {
    public let level: UInt8  // 0-100%
    public let timestamp: Date
    
    public init(level: UInt8, timestamp: Date = Date()) {
        self.level = level
        self.timestamp = timestamp
    }
}

// MARK: - Connection State

public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case scanning
    case connecting(String)
    case connected(String)
    case reconnecting(String)
    case failed(BluetoothKitError)
    
    public var description: String {
        switch self {
        case .disconnected:
            return "Not Connected"
        case .scanning:
            return "Scanning..."
        case .connecting(let deviceName):
            return "Connecting to \(deviceName)..."
        case .connected(let deviceName):
            return "Connected to \(deviceName)"
        case .reconnecting(let deviceName):
            return "Reconnecting to \(deviceName)..."
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
    
    // Manual Equatable implementation
    public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected), (.scanning, .scanning):
            return true
        case (.connecting(let lhsName), .connecting(let rhsName)):
            return lhsName == rhsName
        case (.connected(let lhsName), .connected(let rhsName)):
            return lhsName == rhsName
        case (.reconnecting(let lhsName), .reconnecting(let rhsName)):
            return lhsName == rhsName
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Recording State

public enum RecordingState: Sendable {
    case idle
    case recording
    case stopping
    
    public var isRecording: Bool {
        return self == .recording
    }
}

// MARK: - Configuration

/// Configuration settings for sensor data collection and device communication.
///
/// Use this structure to customize the basic behavior of BluetoothKit.
///
/// ## Example
///
/// ```swift
/// // Default configuration
/// let defaultConfig = SensorConfiguration.default
///
/// // Custom sample rates
/// let customConfig = SensorConfiguration(
///     eegSampleRate: 500.0,
///     ppgSampleRate: 100.0,
///     deviceNamePrefix: "MyDevice-"
/// )
/// ```
public struct SensorConfiguration: Sendable {
    
    /// EEG sampling rate in Hz.
    ///
    /// Typical values: 125Hz, 250Hz, 500Hz, 1000Hz
    public let eegSampleRate: Double
    
    /// PPG sampling rate in Hz.
    ///
    /// Typical values: 25Hz, 50Hz, 100Hz
    public let ppgSampleRate: Double
    
    /// Accelerometer sampling rate in Hz.
    ///
    /// Typical values: 10Hz, 30Hz, 50Hz, 100Hz
    public let accelerometerSampleRate: Double
    
    /// Prefix for filtering discoverable devices.
    ///
    /// Only devices whose names start with this prefix will be discovered during scanning.
    public let deviceNamePrefix: String
    
    /// Whether to automatically reconnect when connection is lost.
    public let autoReconnectEnabled: Bool
    
    // MARK: - Internal hardware parameters (fixed values)
    
    internal let eegVoltageReference: Double = 4.033
    internal let eegGain: Double = 12.0
    internal let eegResolution: Double = 8388607 // 2^23 - 1
    internal let microVoltMultiplier: Double = 1e6
    internal let timestampDivisor: Double = 32.768
    internal let millisecondsToSeconds: Double = 1000.0
    internal let eegPacketSize: Int = 179
    internal let ppgPacketSize: Int = 172
    internal let eegSamplesPerPacket: Int = 25
    internal let ppgSamplesPerPacket: Int = 28
    internal let eegSampleSize: Int = 7
    internal let ppgSampleSize: Int = 6
    internal let eegValidRange: ClosedRange<Double> = -200.0...200.0
    internal let ppgMaxValue: Int = 16777215
    
    /// Creates a new sensor configuration.
    ///
    /// - Parameters:
    ///   - eegSampleRate: EEG sampling rate in Hz. Default: 250.0
    ///   - ppgSampleRate: PPG sampling rate in Hz. Default: 50.0
    ///   - accelerometerSampleRate: Accelerometer sampling rate in Hz. Default: 30.0
    ///   - deviceNamePrefix: Device name filter prefix. Default: "LXB-"
    ///   - autoReconnectEnabled: Enable automatic reconnection. Default: true
    public init(
        eegSampleRate: Double = 250.0,
        ppgSampleRate: Double = 50.0,
        accelerometerSampleRate: Double = 30.0,
        deviceNamePrefix: String = "LXB-",
        autoReconnectEnabled: Bool = true
    ) {
        self.eegSampleRate = eegSampleRate
        self.ppgSampleRate = ppgSampleRate
        self.accelerometerSampleRate = accelerometerSampleRate
        self.deviceNamePrefix = deviceNamePrefix
        self.autoReconnectEnabled = autoReconnectEnabled
    }
    
    /// Default configuration for typical biomedical data collection.
    public static let `default` = SensorConfiguration()
    
    /// High-performance configuration for research applications.
    public static let highPerformance = SensorConfiguration(
        eegSampleRate: 500.0,
        ppgSampleRate: 100.0,
        accelerometerSampleRate: 100.0
    )
    
    /// Low-power configuration for extended monitoring.
    public static let lowPower = SensorConfiguration(
        eegSampleRate: 125.0,
        ppgSampleRate: 25.0,
        accelerometerSampleRate: 10.0
    )
}

// MARK: - Sensor UUIDs (Internal)

/// Internal structure containing Bluetooth service and characteristic UUIDs.
///
/// These UUIDs define the Bluetooth Low Energy GATT profile for sensor communication.
/// They are specific to the sensor hardware being used and may need to be updated
/// for different device manufacturers.
internal struct SensorUUID {
    // MARK: - EEG Service
    
    /// EEG service UUID (shared service for notify and write operations)
    static var eegService: CBUUID { CBUUID(string: "df7b5d95-3afe-00a1-084c-b50895ef4f95") }
    
    /// EEG notification characteristic UUID (for receiving data)
    static var eegNotifyChar: CBUUID { CBUUID(string: "00ab4d15-66b4-0d8a-824f-8d6f8966c6e5") }
    
    /// EEG write characteristic UUID (for sending commands)
    static var eegWriteChar: CBUUID { CBUUID(string: "0065cacb-9e52-21bf-a849-99a80d83830e") }

    // MARK: - PPG Service
    
    /// PPG service UUID
    static var ppgService: CBUUID { CBUUID(string: "1cc50ec0-6967-9d84-a243-c2267f924d1f") }
    
    /// PPG characteristic UUID (for receiving photoplethysmography data)
    static var ppgChar: CBUUID { CBUUID(string: "6c739642-23ba-818b-2045-bfe8970263f6") }

    // MARK: - Accelerometer Service
    
    /// Accelerometer service UUID
    static var accelService: CBUUID { CBUUID(string: "75c276c3-8f97-20bc-a143-b354244886d4") }
    
    /// Accelerometer characteristic UUID (for receiving motion data)
    static var accelChar: CBUUID { CBUUID(string: "d3d46a35-4394-e9aa-5a43-e7921120aaed") }

    // MARK: - Battery Service
    
    /// Standard Bluetooth SIG Battery Service UUID
    static var batteryService: CBUUID { CBUUID(string: "0000180f-0000-1000-8000-00805f9b34fb") }
    
    /// Standard Bluetooth SIG Battery Level Characteristic UUID
    static var batteryChar: CBUUID { CBUUID(string: "00002a19-0000-1000-8000-00805f9b34fb") }
    
    // MARK: - Convenience Collections
    
    /// All sensor characteristic UUIDs for easy iteration
    static var allSensorCharacteristics: [CBUUID] {
        [eegNotifyChar, ppgChar, accelChar, batteryChar]
    }
}

// MARK: - Logging System

public enum LogLevel: Int, Sendable, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    public var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

public protocol BluetoothKitLogger: Sendable {
    func log(_ message: String, level: LogLevel, file: String, function: String, line: Int)
}

public struct DefaultLogger: BluetoothKitLogger {
    public let minimumLevel: LogLevel
    
    public init(minimumLevel: LogLevel = .info) {
        self.minimumLevel = minimumLevel
    }
    
    public func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        guard level.rawValue >= minimumLevel.rawValue else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("[\(timestamp)] \(level.emoji) \(level.name) [\(fileName):\(line)] \(message)")
    }
}

public struct SilentLogger: BluetoothKitLogger {
    public init() {}
    
    public func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        // Do nothing
    }
}

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Protocols

public protocol SensorDataDelegate: AnyObject, Sendable {
    func didReceiveEEGData(_ reading: EEGReading)
    func didReceivePPGData(_ reading: PPGReading)
    func didReceiveAccelerometerData(_ reading: AccelerometerReading)
    func didReceiveBatteryData(_ reading: BatteryReading)
}

public protocol BluetoothManagerDelegate: AnyObject, Sendable {
    func bluetoothManager(_ manager: AnyObject, didUpdateState state: ConnectionState)
    func bluetoothManager(_ manager: AnyObject, didDiscoverDevice device: BluetoothDevice)
    func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice)
    func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?)
}

public protocol DataRecorderDelegate: AnyObject, Sendable {
    func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date)
    func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL])
    func dataRecorder(_ recorder: AnyObject, didFailWithError error: Error)
}

// MARK: - Errors

public enum BluetoothKitError: LocalizedError, Sendable, Equatable {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed(String)
    case dataParsingFailed(String)
    case recordingFailed(String)
    case fileOperationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available"
        case .deviceNotFound:
            return "Device not found"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .dataParsingFailed(let reason):
            return "Data parsing failed: \(reason)"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
    
    // Manual Equatable implementation
    public static func == (lhs: BluetoothKitError, rhs: BluetoothKitError) -> Bool {
        switch (lhs, rhs) {
        case (.bluetoothUnavailable, .bluetoothUnavailable), (.deviceNotFound, .deviceNotFound):
            return true
        case (.connectionFailed(let lhsReason), .connectionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.dataParsingFailed(let lhsReason), .dataParsingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.recordingFailed(let lhsReason), .recordingFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.fileOperationFailed(let lhsReason), .fileOperationFailed(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
} 