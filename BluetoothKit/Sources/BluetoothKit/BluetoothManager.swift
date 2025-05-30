import Foundation
import CoreBluetooth

// MARK: - Bluetooth Manager

/// Internal class responsible for managing Bluetooth Low Energy connections and device discovery.
///
/// This class handles the CoreBluetooth stack and provides a clean interface for
/// device scanning, connection management, and data streaming. It implements
/// proper concurrency safety using dispatch queues.
public class BluetoothManager: NSObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    public weak var delegate: BluetoothManagerDelegate?
    public weak var sensorDataDelegate: SensorDataDelegate?
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var discoveredDevices: [BluetoothDevice] = []
    
    private let configuration: SensorConfiguration
    private let dataParser: SensorDataParser
    private let logger: BluetoothKitLogger
    
    // Connection state management
    private var connectionState: ConnectionState = .disconnected {
        didSet {
            let currentState = connectionState
            notifyStateChange(currentState)
        }
    }
    
    // Auto-reconnection state
    private var lastConnectedPeripheralIdentifier: UUID?
    private var userInitiatedDisconnect = false
    private var isAutoReconnectEnabled: Bool
    
    // MARK: - Initialization
    
    /// Creates a new BluetoothManager instance.
    ///
    /// - Parameters:
    ///   - configuration: Sensor configuration settings
    ///   - logger: Logger implementation for debugging
    public init(configuration: SensorConfiguration, logger: BluetoothKitLogger) {
        self.configuration = configuration
        self.logger = logger
        self.dataParser = SensorDataParser(configuration: configuration)
        self.isAutoReconnectEnabled = configuration.autoReconnectEnabled
        
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        log("BluetoothManager initialized", level: .info)
    }
    
    // MARK: - Public Interface
    
    public var isScanning: Bool {
        return centralManager.isScanning
    }
    
    public var isConnected: Bool {
        return connectedPeripheral?.state == .connected
    }
    
    public var currentConnectionState: ConnectionState {
        return connectionState
    }
    
    public var discoveredDevicesList: [BluetoothDevice] {
        return discoveredDevices
    }
    
    public func startScanning() {
        guard centralManager.state == .poweredOn else {
            log("Cannot start scanning: Bluetooth not available", level: .warning)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            return
        }
        
        centralManager.stopScan()
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil)
        connectionState = .scanning
        
        log("Started scanning for devices", level: .info)
    }
    
    public func stopScanning() {
        centralManager.stopScan()
        if case .scanning = connectionState {
            connectionState = .disconnected
        }
        log("Stopped scanning", level: .info)
    }
    
    public func connect(to device: BluetoothDevice) {
        guard centralManager.state == .poweredOn else {
            log("Cannot connect: Bluetooth not available", level: .warning)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            return
        }
        
        stopScanning()
        userInitiatedDisconnect = false
        connectionState = .connecting(device.name)
        centralManager.connect(device.peripheral, options: nil)
        
        log("Attempting to connect to \(device.name)", level: .info)
    }
    
    public func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        userInitiatedDisconnect = true
        lastConnectedPeripheralIdentifier = nil
        centralManager.cancelPeripheralConnection(peripheral)
        
        log("Disconnecting from device", level: .info)
    }
    
    public func enableAutoReconnect(_ enabled: Bool) {
        let previousState = isAutoReconnectEnabled
        isAutoReconnectEnabled = enabled
        log("Auto-reconnect \(enabled ? "enabled" : "disabled") (was \(previousState ? "enabled" : "disabled"))", level: .info)
        
        if enabled {
            // If auto-reconnect is being enabled and we have a last connected device,
            // and we're currently disconnected, attempt to reconnect
            if let lastPeripheralId = lastConnectedPeripheralIdentifier,
               !isConnected,
               centralManager.state == .poweredOn {
                
                // Find the peripheral from discovered devices or try to retrieve it
                if let peripheral = discoveredDevices.first(where: { $0.peripheral.identifier == lastPeripheralId })?.peripheral {
                    connectionState = .reconnecting(peripheral.name ?? "Unknown Device")
                    centralManager.connect(peripheral, options: nil)
                    log("Auto-reconnect triggered: attempting to reconnect to \(peripheral.name ?? "Unknown Device")", level: .info)
                } else {
                    // If the peripheral is not in discovered devices, try to retrieve it
                    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [lastPeripheralId])
                    if let peripheral = peripherals.first {
                        connectionState = .reconnecting(peripheral.name ?? "Unknown Device")
                        centralManager.connect(peripheral, options: nil)
                        log("Auto-reconnect triggered: attempting to reconnect to retrieved peripheral \(peripheral.name ?? "Unknown Device")", level: .info)
                    }
                }
            }
        } else {
            // If auto-reconnect is being disabled, cancel any ongoing reconnection attempts
            if case .reconnecting(let deviceName) = connectionState {
                // Find the peripheral that we're trying to reconnect to and cancel the connection
                if let lastPeripheralId = lastConnectedPeripheralIdentifier {
                    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [lastPeripheralId])
                    if let peripheral = peripherals.first {
                        centralManager.cancelPeripheralConnection(peripheral)
                        log("Cancelled ongoing reconnection attempt to \(deviceName)", level: .info)
                    }
                }
                connectionState = .disconnected
            }
            log("Auto-reconnect disabled - all automatic reconnection attempts will be blocked", level: .info)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleDeviceDiscovered(_ peripheral: CBPeripheral, rssi: NSNumber) {
        let name = peripheral.name ?? ""
        guard name.hasPrefix(configuration.deviceNamePrefix) else { return }
        
        // Check if device already exists
        if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
            let device = BluetoothDevice(peripheral: peripheral, name: name, rssi: rssi)
            discoveredDevices.append(device)
            
            notifyDeviceDiscovered(device)
            
            log("Discovered device: \(name) (RSSI: \(rssi))", level: .debug)
        }
    }
    
    private func handleConnectionSuccess(_ peripheral: CBPeripheral) {
        // Check if this connection should be allowed
        // If auto-reconnect is disabled and this was not a user-initiated connection, cancel it
        if case .reconnecting = connectionState, !isAutoReconnectEnabled {
            log("Auto-reconnect is disabled, cancelling automatic connection to \(peripheral.name ?? "Unknown Device")", level: .info)
            centralManager.cancelPeripheralConnection(peripheral)
            connectionState = .disconnected
            return
        }
        
        connectedPeripheral = peripheral
        lastConnectedPeripheralIdentifier = peripheral.identifier
        userInitiatedDisconnect = false
        
        let deviceName = peripheral.name ?? "Unknown Device"
        connectionState = .connected(deviceName)
        
        // Start service discovery
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        if let device = discoveredDevices.first(where: { $0.peripheral.identifier == peripheral.identifier }) {
            notifyDeviceConnected(device)
        }
        
        log("Connected to \(deviceName)", level: .info)
    }
    
    private func handleConnectionFailure(_ peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        connectionState = .failed(BluetoothKitError.connectionFailed(errorMessage))
        
        log("Connection failed: \(errorMessage)", level: .error)
    }
    
    private func handleDisconnection(_ peripheral: CBPeripheral, error: Error?) {
        let deviceName = peripheral.name ?? "Unknown Device"
        
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        
        // Handle auto-reconnection
        if !userInitiatedDisconnect,
           let lastID = lastConnectedPeripheralIdentifier,
           peripheral.identifier == lastID {
            
            if isAutoReconnectEnabled {
                connectionState = .reconnecting(deviceName)
                centralManager.connect(peripheral, options: nil)
                log("Auto-reconnecting to \(deviceName)", level: .info)
            } else {
                connectionState = .disconnected
                log("Auto-reconnect is disabled, not attempting to reconnect to \(deviceName)", level: .info)
            }
        } else {
            connectionState = .disconnected
            if userInitiatedDisconnect {
                lastConnectedPeripheralIdentifier = nil
                userInitiatedDisconnect = false
                log("User initiated disconnect, clearing last connected device", level: .debug)
            }
        }
        
        if let device = discoveredDevices.first(where: { $0.peripheral.identifier == peripheral.identifier }) {
            notifyDeviceDisconnected(device, error: error)
        }
        
        let errorInfo = error?.localizedDescription ?? "No error"
        log("Disconnected from \(deviceName): \(errorInfo)", level: .info)
    }
    
    private func handleCharacteristicUpdate(_ characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, error == nil else {
            log("Characteristic update error: \(error?.localizedDescription ?? "Unknown")", level: .warning)
            return
        }
        
        do {
            switch characteristic.uuid {
            case SensorUUID.eegNotifyChar:
                let readings = try dataParser.parseEEGData(data)
                for reading in readings {
                    notifySensorData(reading) { [weak self] data in
                        self?.sensorDataDelegate?.didReceiveEEGData(data)
                    }
                }
                
            case SensorUUID.ppgChar:
                let readings = try dataParser.parsePPGData(data)
                for reading in readings {
                    notifySensorData(reading) { [weak self] data in
                        self?.sensorDataDelegate?.didReceivePPGData(data)
                    }
                }
                
            case SensorUUID.accelChar:
                let readings = try dataParser.parseAccelerometerData(data)
                for reading in readings {
                    notifySensorData(reading) { [weak self] data in
                        self?.sensorDataDelegate?.didReceiveAccelerometerData(data)
                    }
                }
                
            case SensorUUID.batteryChar:
                let reading = try dataParser.parseBatteryData(data)
                notifySensorData(reading) { [weak self] data in
                    self?.sensorDataDelegate?.didReceiveBatteryData(data)
                }
                
            default:
                log("Received data from unknown characteristic: \(characteristic.uuid)", level: .debug)
            }
        } catch {
            log("Data parsing error: \(error)", level: .error)
        }
    }
    
    private func log(_ message: String, level: LogLevel, file: String = #file, function: String = #function, line: Int = #line) {
        logger.log(message, level: level, file: file, function: function, line: line)
    }
    
    // MARK: - Private Helper Methods
    
    private func notifyStateChange(_ state: ConnectionState) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didUpdateState: state)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didUpdateState: state)
            }
        }
    }
    
    private func notifyDeviceDiscovered(_ device: BluetoothDevice) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didDiscoverDevice: device)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didDiscoverDevice: device)
            }
        }
    }
    
    private func notifyDeviceConnected(_ device: BluetoothDevice) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didConnectToDevice: device)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didConnectToDevice: device)
            }
        }
    }
    
    private func notifyDeviceDisconnected(_ device: BluetoothDevice, error: Error?) {
        if Thread.isMainThread {
            delegate?.bluetoothManager(self, didDisconnectFromDevice: device, error: error)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.bluetoothManager(self, didDisconnectFromDevice: device, error: error)
            }
        }
    }
    
    private func notifySensorData<T: Sendable>(_ data: T, callback: @escaping @Sendable (T) -> Void) {
        if Thread.isMainThread {
            callback(data)
        } else {
            DispatchQueue.main.async {
                callback(data)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("📶 Bluetooth is powered on", level: .info)
            if case .failed(let error) = connectionState,
               error == .bluetoothUnavailable {
                connectionState = .disconnected
            }
            
        case .poweredOff:
            log("📵 Bluetooth is powered off", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            
        case .unauthorized:
            log("🚫 Bluetooth access unauthorized", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            
        case .unsupported:
            log("❌ Bluetooth not supported", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
            
        default:
            log("🔄 Bluetooth state: \(central.state.rawValue)", level: .info)
            connectionState = .failed(BluetoothKitError.bluetoothUnavailable)
        }
    }
    
    public func centralManager(_ central: CBCentralManager,
                              didDiscover peripheral: CBPeripheral,
                              advertisementData: [String : Any],
                              rssi RSSI: NSNumber) {
        handleDeviceDiscovered(peripheral, rssi: RSSI)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        handleConnectionSuccess(peripheral)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        handleConnectionFailure(peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        handleDisconnection(peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services, error == nil else {
            log("⚠️ Service discovery error: \(error?.localizedDescription ?? "Unknown")", level: .error)
            return
        }
        
        log("🔍 Discovered \(services.count) services", level: .info)
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics, error == nil else {
            log("⚠️ Characteristic discovery error: \(error?.localizedDescription ?? "Unknown")", level: .error)
            return
        }
        
        log("🔍 Discovered \(characteristics.count) characteristics for service \(service.uuid)", level: .info)
        
        for characteristic in characteristics {
            if SensorUUID.allSensorCharacteristics.contains(characteristic.uuid) {
                peripheral.setNotifyValue(true, for: characteristic)
                log("🔔 Enabled notifications for: \(characteristic.uuid)", level: .info)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral,
                          didUpdateValueFor characteristic: CBCharacteristic,
                          error: Error?) {
        handleCharacteristicUpdate(characteristic, error: error)
    }
    
    public func peripheral(_ peripheral: CBPeripheral,
                          didUpdateNotificationStateFor characteristic: CBCharacteristic,
                          error: Error?) {
        if let error = error {
            log("⚠️ Notification state update error: \(error.localizedDescription)", level: .warning)
        } else {
            log("✅ Notification state updated for: \(characteristic.uuid)", level: .info)
        }
    }
} 