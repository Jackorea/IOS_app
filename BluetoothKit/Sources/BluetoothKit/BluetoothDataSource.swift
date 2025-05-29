import Foundation
import CoreBluetooth
import SwiftUI

// MARK: - Bluetooth Data Source Implementation

/// Bluetooth-specific implementation of SensorDataSource
/// 
/// This class encapsulates all CoreBluetooth dependencies,
/// allowing the main BluetoothKit to be platform-agnostic.
@available(iOS 13.0, macOS 10.15, *)
public class BluetoothDataSource: SensorDataSource, ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    
    @Published public var availableDevices: [SensorDevice] = []
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public var isScanning: Bool = false
    
    // MARK: - Private Properties
    
    private let bluetoothManager: BluetoothManager
    private weak var sensorDataDelegate: SensorDataDelegate?
    private weak var dataSourceDelegate: DataSourceDelegate?
    
    // MARK: - Initialization
    
    public init(configuration: SensorConfiguration = .default) {
        let logger = DefaultLogger()
        self.bluetoothManager = BluetoothManager(configuration: configuration, logger: logger)
        setupDelegates()
    }
    
    // MARK: - SensorDataSource Implementation
    
    public func startScanning() {
        bluetoothManager.startScanning()
    }
    
    public func stopScanning() {
        bluetoothManager.stopScanning()
    }
    
    public func connect(to device: SensorDevice) {
        // Convert SensorDevice back to BluetoothDevice for internal use
        if let bluetoothDevice = findBluetoothDevice(for: device) {
            bluetoothManager.connect(to: bluetoothDevice)
        }
    }
    
    public func disconnect() {
        bluetoothManager.disconnect()
    }
    
    public func setSensorDataDelegate(_ delegate: SensorDataDelegate?) {
        self.sensorDataDelegate = delegate
        bluetoothManager.sensorDataDelegate = delegate
    }
    
    public func setAutoReconnect(enabled: Bool) {
        bluetoothManager.enableAutoReconnect(enabled)
    }
    
    // MARK: - Delegate Management
    
    public func setDataSourceDelegate(_ delegate: DataSourceDelegate?) {
        self.dataSourceDelegate = delegate
    }
    
    // MARK: - Private Methods
    
    private func setupDelegates() {
        bluetoothManager.delegate = self
        bluetoothManager.sensorDataDelegate = self
    }
    
    private var discoveredBluetoothDevices: [BluetoothDevice] = []
    
    private func findBluetoothDevice(for sensorDevice: SensorDevice) -> BluetoothDevice? {
        return discoveredBluetoothDevices.first { device in
            device.peripheral.identifier.uuidString == sensorDevice.id
        }
    }
    
    private func convertToSensorDevice(_ bluetoothDevice: BluetoothDevice) -> SensorDevice {
        return SensorDevice(
            id: bluetoothDevice.peripheral.identifier.uuidString,
            name: bluetoothDevice.name,
            signalStrength: bluetoothDevice.rssi?.intValue,
            deviceType: .bluetooth,
            metadata: [
                "peripheralState": bluetoothDevice.peripheral.state.description,
                "services": bluetoothDevice.peripheral.services?.description ?? "none"
            ]
        )
    }
}

// MARK: - BluetoothManagerDelegate

extension BluetoothDataSource: BluetoothManagerDelegate {
    
    public func bluetoothManager(_ manager: AnyObject, didUpdateState state: ConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state
            self.dataSourceDelegate?.dataSourceDidUpdateState(state)
        }
    }
    
    public func bluetoothManager(_ manager: AnyObject, didDiscoverDevice device: BluetoothDevice) {
        DispatchQueue.main.async {
            // Store the original BluetoothDevice for later conversion
            if !self.discoveredBluetoothDevices.contains(device) {
                self.discoveredBluetoothDevices.append(device)
            }
            
            // Convert to platform-agnostic SensorDevice
            let sensorDevice = self.convertToSensorDevice(device)
            
            if !self.availableDevices.contains(sensorDevice) {
                self.availableDevices.append(sensorDevice)
                self.dataSourceDelegate?.dataSourceDidUpdateDevices(self.availableDevices)
            }
        }
    }
    
    public func bluetoothManager(_ manager: AnyObject, didConnectToDevice device: BluetoothDevice) {
        DispatchQueue.main.async {
            let sensorDevice = self.convertToSensorDevice(device)
            self.dataSourceDelegate?.dataSourceDidConnect(to: sensorDevice)
        }
    }
    
    public func bluetoothManager(_ manager: AnyObject, didDisconnectFromDevice device: BluetoothDevice, error: Error?) {
        DispatchQueue.main.async {
            let sensorDevice = self.convertToSensorDevice(device)
            self.dataSourceDelegate?.dataSourceDidDisconnect(from: sensorDevice, error: error)
        }
    }
}

// MARK: - SensorDataDelegate Passthrough

extension BluetoothDataSource: SensorDataDelegate {
    
    public func didReceiveEEGData(_ reading: EEGReading) {
        sensorDataDelegate?.didReceiveEEGData(reading)
    }
    
    public func didReceivePPGData(_ reading: PPGReading) {
        sensorDataDelegate?.didReceivePPGData(reading)
    }
    
    public func didReceiveAccelerometerData(_ reading: AccelerometerReading) {
        sensorDataDelegate?.didReceiveAccelerometerData(reading)
    }
    
    public func didReceiveBatteryData(_ reading: BatteryReading) {
        sensorDataDelegate?.didReceiveBatteryData(reading)
    }
}

// MARK: - CBPeripheralState Extension

private extension CBPeripheralState {
    var description: String {
        switch self {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }
} 