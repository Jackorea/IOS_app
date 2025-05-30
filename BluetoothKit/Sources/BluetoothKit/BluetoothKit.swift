import Foundation
import SwiftUI
import CoreBluetooth

// MARK: - BluetoothKit Main Interface

/// A comprehensive Bluetooth Low Energy (BLE) library for connecting to sensor devices and collecting biomedical data.
///
/// `BluetoothKit` provides a SwiftUI-friendly interface for:
/// - Scanning and connecting to Bluetooth devices
/// - Receiving real-time sensor data (EEG, PPG, Accelerometer, Battery)
/// - Recording data to files
/// - Managing connection states with automatic reconnection
///
/// ## Usage
///
/// ```swift
/// struct ContentView: View {
///     @StateObject private var bluetoothKit = BluetoothKit()
///     
///     var body: some View {
///         VStack {
///             Button("Start Scanning") {
///                 bluetoothKit.startScanning()
///             }
///             
///             List(bluetoothKit.discoveredDevices) { device in
///                 Button("Connect to \(device.name)") {
///                     bluetoothKit.connect(to: device)
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Configuration
///
/// You can customize the behavior using `SensorConfiguration`:
///
/// ```swift
/// let config = SensorConfiguration(
///     eegSampleRate: 500.0,
///     deviceNamePrefix: "MyDevice-"
/// )
/// let bluetoothKit = BluetoothKit(configuration: config)
/// ```
@available(iOS 13.0, macOS 10.15, *)
public class BluetoothKit: ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties for SwiftUI
    
    /// List of discovered Bluetooth devices during scanning.
    ///
    /// This array is automatically updated when new devices are found during scanning.
    /// Devices are filtered by the configured device name prefix.
    @Published public var discoveredDevices: [BluetoothDevice] = []
    
    /// Current connection state.
    ///
    /// Use this to display connection status in your UI and handle different states:
    /// - `.disconnected`: No active connection
    /// - `.scanning`: Currently scanning for devices  
    /// - `.connecting(deviceName)`: Attempting to connect to a device
    /// - `.connected(deviceName)`: Successfully connected to a device
    /// - `.reconnecting(deviceName)`: Attempting to reconnect after disconnection
    /// - `.failed(error)`: Connection or operation failed
    @Published public var connectionState: ConnectionState = .disconnected
    
    /// Whether the library is currently scanning for devices.
    ///
    /// Use this to show scanning indicators in your UI.
    @Published public var isScanning: Bool = false
    
    /// Whether data recording is currently active.
    ///
    /// When `true`, all received sensor data is being saved to files.
    @Published public var isRecording: Bool = false
    
    /// Whether auto-reconnection is currently enabled.
    ///
    /// When `true`, the library will automatically attempt to reconnect if connection is lost.
    @Published public var isAutoReconnectEnabled: Bool = true
    
    // Latest sensor readings for UI display
    
    /// The most recent EEG (electroencephalogram) reading.
    ///
    /// Contains 2-channel brain activity data in microvolts (µV) and lead-off status.
    /// `nil` if no EEG data has been received yet.
    @Published public var latestEEGReading: EEGReading?
    
    /// The most recent PPG (photoplethysmography) reading.
    ///
    /// Contains red and infrared LED values for heart rate monitoring.
    /// `nil` if no PPG data has been received yet.
    @Published public var latestPPGReading: PPGReading?
    
    /// The most recent accelerometer reading.
    ///
    /// Contains 3-axis acceleration data for motion detection.
    /// `nil` if no accelerometer data has been received yet.
    @Published public var latestAccelerometerReading: AccelerometerReading?
    
    /// The most recent battery level reading.
    ///
    /// Contains battery percentage (0-100%) from the connected device.
    /// `nil` if no battery data has been received yet.
    @Published public var latestBatteryReading: BatteryReading?
    
    /// List of recorded data files.
    ///
    /// Updated automatically when recordings are completed.
    /// Each recording session creates multiple CSV files (one per sensor type).
    @Published public var recordedFiles: [URL] = []
    
    /// Whether to show a Bluetooth disabled alert.
    ///
    /// Automatically set to `true` when Bluetooth is turned off.
    /// Use this to trigger alert presentation in your UI.
    @Published public var showBluetoothOffAlert: Bool = false
    
    // MARK: - Private Components
    
    private let bluetoothManager: BluetoothManager
    private let dataRecorder: DataRecorder
    private let configuration: SensorConfiguration
    private let logger: BluetoothKitLogger
    
    // MARK: - Initialization
    
    /// Creates a new BluetoothKit instance.
    ///
    /// - Parameters:
    ///   - configuration: Sensor configuration settings. Defaults to `.default`.
    ///   - logger: Logger implementation for debugging. Defaults to `DefaultLogger()`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use default configuration
    /// let bluetoothKit = BluetoothKit()
    ///
    /// // Custom configuration with higher sample rates
    /// let config = SensorConfiguration(
    ///     eegSampleRate: 500.0,
    ///     ppgSampleRate: 100.0,
    ///     deviceNamePrefix: "MyDevice-"
    /// )
    /// let bluetoothKit = BluetoothKit(configuration: config)
    ///
    /// // Silent logging for production
    /// let bluetoothKit = BluetoothKit(logger: SilentLogger())
    /// ```
    public init(configuration: SensorConfiguration = .default, logger: BluetoothKitLogger = DefaultLogger()) {
        self.configuration = configuration
        self.logger = logger
        self.bluetoothManager = BluetoothManager(configuration: configuration, logger: logger)
        self.dataRecorder = DataRecorder(logger: logger)
        
        // Initialize auto-reconnect setting from configuration
        self.isAutoReconnectEnabled = configuration.autoReconnectEnabled
        
        setupDelegates()
        updateRecordedFiles()
        
        log("BluetoothKit initialized", level: .info)
    }
    
    // MARK: - Public Interface
    
    /// Start scanning for Bluetooth devices.
    ///
    /// Only devices matching the configured `deviceNamePrefix` will be discovered.
    /// Updates `discoveredDevices` array as devices are found.
    ///
    /// - Note: Ensure Bluetooth is enabled before calling this method.
    ///
    /// ## Example
    ///
    /// ```swift
    /// bluetoothKit.startScanning()
    /// 
    /// // Monitor scanning state
    /// if bluetoothKit.isScanning {
    ///     print("Scanning in progress...")
    /// }
    /// ```
    public func startScanning() {
        log("Starting device scan", level: .info)
        bluetoothManager.startScanning()
    }
    
    /// Stop scanning for Bluetooth devices.
    ///
    /// Cancels any ongoing device discovery process.
    public func stopScanning() {
        log("Stopping device scan", level: .info)
        bluetoothManager.stopScanning()
    }
    
    /// Connect to a specific Bluetooth device.
    ///
    /// - Parameter device: The device to connect to, obtained from `discoveredDevices`.
    ///
    /// Connection progress can be monitored via `connectionState`.
    /// Upon successful connection, sensor data will begin streaming automatically.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let device = bluetoothKit.discoveredDevices.first {
    ///     bluetoothKit.connect(to: device)
    /// }
    /// 
    /// // Monitor connection state
    /// switch bluetoothKit.connectionState {
    /// case .connecting(let deviceName):
    ///     print("Connecting to \(deviceName)...")
    /// case .connected(let deviceName):
    ///     print("Connected to \(deviceName)")
    /// case .failed(let error):
    ///     print("Connection failed: \(error)")
    /// default:
    ///     break
    /// }
    /// ```
    public func connect(to device: BluetoothDevice) {
        log("Attempting to connect to device: \(device.name)", level: .info)
        bluetoothManager.connect(to: device)
    }
    
    /// Disconnect from the currently connected device.
    ///
    /// If recording is active, it will be automatically stopped before disconnection.
    /// Disables auto-reconnection for this disconnection.
    public func disconnect() {
        log("Disconnecting from current device", level: .info)
        // Stop recording if active
        if isRecording {
            stopRecording()
        }
        bluetoothManager.disconnect()
    }
    
    /// Start recording sensor data to files.
    ///
    /// Creates timestamped CSV files for each sensor type in the documents directory.
    /// Recording continues until `stopRecording()` is called.
    ///
    /// - Note: A device must be connected and streaming data for recording to be meaningful.
    ///
    /// ## File Format
    ///
    /// The following CSV files are created:
    /// - `YYYYMMDD_HHMMSS_eeg.csv`: EEG data with timestamp, channel1, channel2, leadOff
    /// - `YYYYMMDD_HHMMSS_ppg.csv`: PPG data with timestamp, red, ir
    /// - `YYYYMMDD_HHMMSS_accel.csv`: Accelerometer data with timestamp, x, y, z
    /// - `YYYYMMDD_HHMMSS_raw.json`: Complete session data in JSON format
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Start recording
    /// bluetoothKit.startRecording()
    /// 
    /// // Monitor recording state
    /// if bluetoothKit.isRecording {
    ///     print("Recording sensor data...")
    /// }
    /// 
    /// // Stop after 30 seconds
    /// DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    ///     bluetoothKit.stopRecording()
    /// }
    /// ```
    public func startRecording() {
        log("Starting data recording", level: .info)
        dataRecorder.startRecording()
    }
    
    /// Stop recording sensor data.
    ///
    /// Finalizes and saves all data files. The `recordedFiles` array will be updated
    /// with the URLs of the saved files.
    public func stopRecording() {
        log("Stopping data recording", level: .info)
        dataRecorder.stopRecording()
    }
    
    /// Get the directory where recordings are saved.
    ///
    /// - Returns: URL to the documents directory where CSV and JSON files are stored.
    ///
    /// Use this to access recorded files programmatically or for sharing functionality.
    public var recordingsDirectory: URL {
        return dataRecorder.recordingsDirectory
    }
    
    /// Check if currently connected to a device.
    ///
    /// - Returns: `true` if a device is connected and ready for data streaming.
    public var isConnected: Bool {
        return bluetoothManager.isConnected
    }
    
    /// Get current connection status description.
    ///
    /// - Returns: Human-readable string describing the current connection state.
    ///
    /// Useful for displaying status in UI labels.
    public var connectionStatusDescription: String {
        return connectionState.description
    }
    
    /// Enable or disable auto-reconnection.
    ///
    /// - Parameter enabled: Whether to automatically reconnect when connection is lost.
    ///
    /// When enabled, the library will automatically attempt to reconnect to the last
    /// connected device if the connection is lost unexpectedly (not due to user action).
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Enable auto-reconnect for robust connections
    /// bluetoothKit.setAutoReconnect(enabled: true)
    /// 
    /// // Disable for manual connection control
    /// bluetoothKit.setAutoReconnect(enabled: false)
    /// ```
    public func setAutoReconnect(enabled: Bool) {
        log("Auto-reconnect \(enabled ? "enabled" : "disabled")", level: .info)
        isAutoReconnectEnabled = enabled
        bluetoothManager.enableAutoReconnect(enabled)
    }
    
    // MARK: - Private Setup
    
    private func setupDelegates() {
        bluetoothManager.delegate = self
        bluetoothManager.sensorDataDelegate = self
        dataRecorder.delegate = self
    }
    
    private func updateRecordedFiles() {
        recordedFiles = dataRecorder.getRecordedFiles()
    }
    
    private func log(_ message: String, level: LogLevel, file: String = #file, function: String = #function, line: Int = #line) {
        logger.log(message, level: level, file: file, function: function, line: line)
    }
}

// MARK: - BluetoothManagerDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: BluetoothManagerDelegate {
    
    public func bluetoothManager(_ manager: AnyObject, didUpdateState state: ConnectionState) {
        connectionState = state
        isScanning = bluetoothManager.isScanning
        
        // Handle Bluetooth off alert
        if case .failed(let error) = state,
           let bluetoothError = error as? BluetoothKitError,
           bluetoothError == .bluetoothUnavailable {
            showBluetoothOffAlert = true
        } else {
            showBluetoothOffAlert = false
        }
    }
    
    public func bluetoothManager(_ manager: AnyObject, didDiscoverDevice device: BluetoothDevice) {
        if !discoveredDevices.contains(device) {
            discoveredDevices.append(device)
        }
    }
    
    public func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice) {
        log("Successfully connected to \(device.name)", level: .info)
    }
    
    public func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?) {
        if let error = error {
            log("Disconnected from \(device.name) with error: \(error.localizedDescription)", level: .warning)
        } else {
            log("Disconnected from \(device.name)", level: .info)
        }
    }
}

// MARK: - SensorDataDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: SensorDataDelegate {
    
    public func didReceiveEEGData(_ reading: EEGReading) {
        latestEEGReading = reading
        
        // Record if recording is active
        if isRecording {
            dataRecorder.recordEEGData([reading])
        }
        
        // Log live data for debugging
        let status = reading.leadOff ? "Disconnected" : "Connected"
        log("EEG Live - CH1: \(String(format: "%.1f", reading.channel1)) µV, CH2: \(String(format: "%.1f", reading.channel2)) µV, Status: \(status)", level: .debug)
    }
    
    public func didReceivePPGData(_ reading: PPGReading) {
        latestPPGReading = reading
        
        // Record if recording is active
        if isRecording {
            dataRecorder.recordPPGData([reading])
        }
        
        // Log live data for debugging
        log("PPG Live - Red: \(reading.red), IR: \(reading.ir)", level: .debug)
    }
    
    public func didReceiveAccelerometerData(_ reading: AccelerometerReading) {
        latestAccelerometerReading = reading
        
        // Record if recording is active
        if isRecording {
            dataRecorder.recordAccelerometerData([reading])
        }
        
        // Log live data for debugging
        log("Accel Live - X: \(reading.x), Y: \(reading.y), Z: \(reading.z)", level: .debug)
    }
    
    public func didReceiveBatteryData(_ reading: BatteryReading) {
        latestBatteryReading = reading
        
        // Record if recording is active
        if isRecording {
            dataRecorder.recordBatteryData(reading)
        }
        
        log("Battery: \(reading.level)%", level: .debug)
    }
}

// MARK: - DataRecorderDelegate

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit: DataRecorderDelegate {
    
    public func dataRecorder(_ recorder: AnyObject, didStartRecording at: Date) {
        isRecording = true
        log("Recording started at \(at)", level: .info)
    }
    
    public func dataRecorder(_ recorder: AnyObject, didStopRecording at: Date, savedFiles: [URL]) {
        isRecording = false
        updateRecordedFiles()
        log("Recording stopped at \(at). Saved \(savedFiles.count) files", level: .info)
    }
    
    public func dataRecorder(_ recorder: AnyObject, didFailWithError error: Error) {
        isRecording = false
        log("Recording error: \(error.localizedDescription)", level: .error)
    }
}

// MARK: - Convenience Extensions

@available(iOS 13.0, macOS 10.15, *)
extension BluetoothKit {
    
    /// Get the latest sensor readings as a tuple for easy access
    public var latestReadings: (eeg: EEGReading?, ppg: PPGReading?, accel: AccelerometerReading?, battery: BatteryReading?) {
        return (latestEEGReading, latestPPGReading, latestAccelerometerReading, latestBatteryReading)
    }
    
    /// Check if any sensor data has been received
    public var hasReceivedData: Bool {
        return latestEEGReading != nil || latestPPGReading != nil || latestAccelerometerReading != nil
    }
    
    /// Get connection state as a simple boolean for UI binding
    public var isConnectedBinding: Bool {
        if case .connected = connectionState {
            return true
        }
        return false
    }
    
    /// Get scanning state for UI binding
    public var isScanningBinding: Bool {
        if case .scanning = connectionState {
            return true
        }
        return false
    }
} 