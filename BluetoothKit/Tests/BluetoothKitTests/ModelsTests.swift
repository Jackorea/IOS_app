import XCTest
@testable import BluetoothKit
import Foundation
import CoreBluetooth

final class ModelsTests: XCTestCase {
    
    // MARK: - BluetoothDevice Tests
    
    func testBluetoothDeviceEquality() {
        // Given
        let mockPeripheral1 = MockCBPeripheral(identifier: UUID(), name: "Test Device 1")
        let mockPeripheral2 = MockCBPeripheral(identifier: UUID(), name: "Test Device 2")
        let samePeripheral = mockPeripheral1
        
        let device1 = BluetoothDevice(peripheral: mockPeripheral1, name: "Test Device 1")
        let device2 = BluetoothDevice(peripheral: mockPeripheral2, name: "Test Device 2")
        let device3 = BluetoothDevice(peripheral: samePeripheral, name: "Same Device")
        
        // When & Then
        XCTAssertNotEqual(device1, device2, "Devices with different peripherals should not be equal")
        XCTAssertEqual(device1, device3, "Devices with same peripheral should be equal")
    }
    
    // MARK: - ConnectionState Tests
    
    func testConnectionStateDescription() {
        // Given & When & Then
        XCTAssertEqual(ConnectionState.disconnected.description, "Not Connected")
        XCTAssertEqual(ConnectionState.scanning.description, "Scanning...")
        XCTAssertEqual(ConnectionState.connecting("TestDevice").description, "Connecting to TestDevice...")
        XCTAssertEqual(ConnectionState.connected("TestDevice").description, "Connected to TestDevice")
        XCTAssertEqual(ConnectionState.reconnecting("TestDevice").description, "Reconnecting to TestDevice...")
        
        let error = BluetoothKitError.connectionFailed("Test error")
        XCTAssertTrue(ConnectionState.failed(error).description.contains("Failed"))
    }
    
    func testConnectionStateEquality() {
        // Given
        let error1 = BluetoothKitError.connectionFailed("Error 1")
        let error2 = BluetoothKitError.connectionFailed("Error 2")
        let sameError = BluetoothKitError.connectionFailed("Error 1")
        
        // When & Then
        XCTAssertEqual(ConnectionState.disconnected, ConnectionState.disconnected)
        XCTAssertEqual(ConnectionState.scanning, ConnectionState.scanning)
        XCTAssertEqual(ConnectionState.connecting("Device"), ConnectionState.connecting("Device"))
        XCTAssertEqual(ConnectionState.connected("Device"), ConnectionState.connected("Device"))
        XCTAssertEqual(ConnectionState.reconnecting("Device"), ConnectionState.reconnecting("Device"))
        XCTAssertEqual(ConnectionState.failed(error1), ConnectionState.failed(sameError))
        
        XCTAssertNotEqual(ConnectionState.connecting("Device1"), ConnectionState.connecting("Device2"))
        XCTAssertNotEqual(ConnectionState.failed(error1), ConnectionState.failed(error2))
        XCTAssertNotEqual(ConnectionState.disconnected, ConnectionState.scanning)
    }
    
    // MARK: - RecordingState Tests
    
    func testRecordingStateIsRecording() {
        // Given & When & Then
        XCTAssertFalse(RecordingState.idle.isRecording)
        XCTAssertTrue(RecordingState.recording.isRecording)
        XCTAssertFalse(RecordingState.stopping.isRecording)
    }
    
    // MARK: - SensorConfiguration Tests
    
    func testSensorConfigurationDefault() {
        // Given
        let config = SensorConfiguration.default
        
        // When & Then
        XCTAssertEqual(config.eegSampleRate, 250.0)
        XCTAssertEqual(config.ppgSampleRate, 50.0)
        XCTAssertEqual(config.accelerometerSampleRate, 30.0)
        XCTAssertEqual(config.deviceNamePrefix, "LXB-")
        XCTAssertTrue(config.autoReconnectEnabled)
    }
    
    func testSensorConfigurationCustom() {
        // Given
        let customConfig = SensorConfiguration(
            eegSampleRate: 500.0,
            ppgSampleRate: 100.0,
            accelerometerSampleRate: 60.0,
            deviceNamePrefix: "CUSTOM-",
            autoReconnectEnabled: false
        )
        
        // When & Then
        XCTAssertEqual(customConfig.eegSampleRate, 500.0)
        XCTAssertEqual(customConfig.ppgSampleRate, 100.0)
        XCTAssertEqual(customConfig.accelerometerSampleRate, 60.0)
        XCTAssertEqual(customConfig.deviceNamePrefix, "CUSTOM-")
        XCTAssertFalse(customConfig.autoReconnectEnabled)
    }
    
    // MARK: - Sensor Reading Tests
    
    func testEEGReadingCreation() {
        // Given
        let channel1 = 123.45
        let channel2 = -67.89
        let leadOff = true
        let timestamp = Date()
        
        // When
        let reading = EEGReading(
            channel1: channel1,
            channel2: channel2,
            leadOff: leadOff,
            timestamp: timestamp
        )
        
        // Then
        XCTAssertEqual(reading.channel1, channel1)
        XCTAssertEqual(reading.channel2, channel2)
        XCTAssertEqual(reading.leadOff, leadOff)
        XCTAssertEqual(reading.timestamp, timestamp)
    }
    
    func testPPGReadingCreation() {
        // Given
        let red = 1000
        let ir = 1500
        let timestamp = Date()
        
        // When
        let reading = PPGReading(red: red, ir: ir, timestamp: timestamp)
        
        // Then
        XCTAssertEqual(reading.red, red)
        XCTAssertEqual(reading.ir, ir)
        XCTAssertEqual(reading.timestamp, timestamp)
    }
    
    func testAccelerometerReadingCreation() {
        // Given
        let x: Int16 = 100
        let y: Int16 = -200
        let z: Int16 = 300
        let timestamp = Date()
        
        // When
        let reading = AccelerometerReading(x: x, y: y, z: z, timestamp: timestamp)
        
        // Then
        XCTAssertEqual(reading.x, x)
        XCTAssertEqual(reading.y, y)
        XCTAssertEqual(reading.z, z)
        XCTAssertEqual(reading.timestamp, timestamp)
    }
    
    func testBatteryReadingCreation() {
        // Given
        let level: UInt8 = 85
        let timestamp = Date()
        
        // When
        let reading = BatteryReading(level: level, timestamp: timestamp)
        
        // Then
        XCTAssertEqual(reading.level, level)
        XCTAssertEqual(reading.timestamp, timestamp)
    }
    
    // MARK: - LogLevel Tests
    
    func testLogLevelProperties() {
        // Given & When & Then
        XCTAssertEqual(LogLevel.debug.emoji, "🔍")
        XCTAssertEqual(LogLevel.info.emoji, "ℹ️")
        XCTAssertEqual(LogLevel.warning.emoji, "⚠️")
        XCTAssertEqual(LogLevel.error.emoji, "❌")
        
        XCTAssertEqual(LogLevel.debug.name, "DEBUG")
        XCTAssertEqual(LogLevel.info.name, "INFO")
        XCTAssertEqual(LogLevel.warning.name, "WARNING")
        XCTAssertEqual(LogLevel.error.name, "ERROR")
        
        XCTAssertEqual(LogLevel.debug.rawValue, 0)
        XCTAssertEqual(LogLevel.info.rawValue, 1)
        XCTAssertEqual(LogLevel.warning.rawValue, 2)
        XCTAssertEqual(LogLevel.error.rawValue, 3)
    }
    
    // MARK: - BluetoothKitError Tests
    
    func testBluetoothKitErrorDescription() {
        // Given & When & Then
        XCTAssertEqual(
            BluetoothKitError.bluetoothUnavailable.errorDescription,
            "Bluetooth is not available"
        )
        XCTAssertEqual(
            BluetoothKitError.deviceNotFound.errorDescription,
            "Device not found"
        )
        XCTAssertEqual(
            BluetoothKitError.connectionFailed("test").errorDescription,
            "Connection failed: test"
        )
        XCTAssertEqual(
            BluetoothKitError.dataParsingFailed("parse error").errorDescription,
            "Data parsing failed: parse error"
        )
        XCTAssertEqual(
            BluetoothKitError.recordingFailed("record error").errorDescription,
            "Recording failed: record error"
        )
        XCTAssertEqual(
            BluetoothKitError.fileOperationFailed("file error").errorDescription,
            "File operation failed: file error"
        )
    }
    
    func testBluetoothKitErrorEquality() {
        // Given
        let error1 = BluetoothKitError.connectionFailed("Error 1")
        let error2 = BluetoothKitError.connectionFailed("Error 2")
        let sameError = BluetoothKitError.connectionFailed("Error 1")
        
        // When & Then
        XCTAssertEqual(BluetoothKitError.bluetoothUnavailable, BluetoothKitError.bluetoothUnavailable)
        XCTAssertEqual(BluetoothKitError.deviceNotFound, BluetoothKitError.deviceNotFound)
        XCTAssertEqual(error1, sameError)
        XCTAssertNotEqual(error1, error2)
        XCTAssertNotEqual(BluetoothKitError.bluetoothUnavailable, BluetoothKitError.deviceNotFound)
    }
    
    // MARK: - Logger Tests
    
    func testDefaultLogger() {
        // Given
        let logger = DefaultLogger(minimumLevel: .warning)
        
        // When & Then - This would normally print to console, 
        // but we're just testing it doesn't crash
        logger.log("Test message", level: .error, file: #file, function: #function, line: #line)
        logger.log("This should be filtered", level: .debug, file: #file, function: #function, line: #line)
    }
    
    func testSilentLogger() {
        // Given
        let logger = SilentLogger()
        
        // When & Then - Should not print anything
        logger.log("Test message", level: .error, file: #file, function: #function, line: #line)
    }
}

// MARK: - Mock Objects

class MockCBPeripheral: CBPeripheral {
    private let mockIdentifier: UUID
    private let mockName: String?
    
    init(identifier: UUID, name: String?) {
        self.mockIdentifier = identifier
        self.mockName = name
        super.init()
    }
    
    override var identifier: UUID {
        return mockIdentifier
    }
    
    override var name: String? {
        return mockName
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
} 