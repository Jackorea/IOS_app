import XCTest
@testable import BluetoothKit
import Foundation

final class SensorDataParserTests: XCTestCase {
    
    var parser: SensorDataParser!
    
    override func setUpWithError() throws {
        parser = SensorDataParser()
    }
    
    override func tearDownWithError() throws {
        parser = nil
    }
    
    // MARK: - EEG Data Parsing Tests
    
    func testEEGDataParsingValidPacket() throws {
        // Given: Valid EEG packet (179 bytes)
        var data = Data(count: 179)
        
        // Header with timestamp (4 bytes)
        data[0] = 0x00  // LSB
        data[1] = 0x10
        data[2] = 0x20
        data[3] = 0x30  // MSB
        
        // First sample (7 bytes): leadOff=0, ch1=100, ch2=200
        data[4] = 0x00  // leadOff
        data[5] = 0x00  // ch1 MSB
        data[6] = 0x00  // ch1 MID
        data[7] = 0x64  // ch1 LSB (100)
        data[8] = 0x00  // ch2 MSB
        data[9] = 0x00  // ch2 MID
        data[10] = 0xC8 // ch2 LSB (200)
        
        // When
        let readings = try parser.parseEEGData(data)
        
        // Then
        XCTAssertEqual(readings.count, 25, "EEG packet should contain 25 samples")
        
        let firstReading = readings[0]
        XCTAssertFalse(firstReading.leadOff, "LeadOff should be false when byte is 0")
        XCTAssertNotNil(firstReading.timestamp)
    }
    
    func testEEGDataParsingInvalidLength() throws {
        // Given: Invalid packet length
        let data = Data(count: 100)
        
        // When & Then
        XCTAssertThrowsError(try parser.parseEEGData(data)) { error in
            guard case BluetoothKitError.dataParsingFailed(let message) = error else {
                XCTFail("Expected dataParsingFailed error")
                return
            }
            XCTAssertTrue(message.contains("179"), "Error should mention expected packet size")
        }
    }
    
    func testEEGDataLeadOffDetection() throws {
        // Given: Packet with leadOff=1
        var data = Data(count: 179)
        data[4] = 0x01  // leadOff = true
        
        // When
        let readings = try parser.parseEEGData(data)
        
        // Then
        XCTAssertTrue(readings[0].leadOff, "LeadOff should be true when byte > 0")
    }
    
    // MARK: - PPG Data Parsing Tests
    
    func testPPGDataParsingValidPacket() throws {
        // Given: Valid PPG packet (172 bytes)
        var data = Data(count: 172)
        
        // Header with timestamp
        data[0] = 0x00
        data[1] = 0x10
        data[2] = 0x20
        data[3] = 0x30
        
        // First sample (6 bytes): red=100, ir=200
        data[4] = 0x00  // red MSB
        data[5] = 0x00  // red MID
        data[6] = 0x64  // red LSB (100)
        data[7] = 0x00  // ir MSB
        data[8] = 0x00  // ir MID
        data[9] = 0xC8  // ir LSB (200)
        
        // When
        let readings = try parser.parsePPGData(data)
        
        // Then
        XCTAssertEqual(readings.count, 28, "PPG packet should contain 28 samples")
        
        let firstReading = readings[0]
        XCTAssertEqual(firstReading.red, 100)
        XCTAssertEqual(firstReading.ir, 200)
    }
    
    func testPPGDataParsingInvalidLength() throws {
        // Given: Invalid packet length
        let data = Data(count: 50)
        
        // When & Then
        XCTAssertThrowsError(try parser.parsePPGData(data)) { error in
            guard case BluetoothKitError.dataParsingFailed(let message) = error else {
                XCTFail("Expected dataParsingFailed error")
                return
            }
            XCTAssertTrue(message.contains("172"), "Error should mention expected packet size")
        }
    }
    
    // MARK: - Accelerometer Data Parsing Tests
    
    func testAccelerometerDataParsingValidPacket() throws {
        // Given: Valid accelerometer packet (10 bytes = 4 header + 6 data)
        var data = Data(count: 10)
        
        // Header
        data[0] = 0x00
        data[1] = 0x10
        data[2] = 0x20
        data[3] = 0x30
        
        // Sample data (using odd indices as per parser logic)
        data[4] = 0x00  // unused
        data[5] = 0x10  // x = 16
        data[6] = 0x00  // unused
        data[7] = 0x20  // y = 32
        data[8] = 0x00  // unused
        data[9] = 0x30  // z = 48
        
        // When
        let readings = try parser.parseAccelerometerData(data)
        
        // Then
        XCTAssertEqual(readings.count, 1, "Should parse 1 accelerometer sample")
        
        let reading = readings[0]
        XCTAssertEqual(reading.x, 16)
        XCTAssertEqual(reading.y, 32)
        XCTAssertEqual(reading.z, 48)
    }
    
    func testAccelerometerDataTooShort() throws {
        // Given: Too short packet
        let data = Data(count: 5)
        
        // When & Then
        XCTAssertThrowsError(try parser.parseAccelerometerData(data)) { error in
            guard case BluetoothKitError.dataParsingFailed = error else {
                XCTFail("Expected dataParsingFailed error")
                return
            }
        }
    }
    
    // MARK: - Battery Data Parsing Tests
    
    func testBatteryDataParsingValid() throws {
        // Given: Valid battery data
        let data = Data([85]) // 85%
        
        // When
        let reading = try parser.parseBatteryData(data)
        
        // Then
        XCTAssertEqual(reading.level, 85)
    }
    
    func testBatteryDataParsingEmpty() throws {
        // Given: Empty data
        let data = Data()
        
        // When & Then
        XCTAssertThrowsError(try parser.parseBatteryData(data)) { error in
            guard case BluetoothKitError.dataParsingFailed(let message) = error else {
                XCTFail("Expected dataParsingFailed error")
                return
            }
            XCTAssertTrue(message.contains("empty"), "Error should mention empty data")
        }
    }
    
    // MARK: - Data Validation Tests
    
    func testEEGReadingValidation() {
        // Given: Valid EEG reading
        let validReading = EEGReading(channel1: 50.0, channel2: -30.0, leadOff: false)
        
        // When & Then
        XCTAssertTrue(parser.validateEEGReading(validReading))
        
        // Given: Invalid EEG reading (out of range)
        let invalidReading = EEGReading(channel1: 300.0, channel2: -300.0, leadOff: false)
        
        // When & Then
        XCTAssertFalse(parser.validateEEGReading(invalidReading))
    }
    
    func testPPGReadingValidation() {
        // Given: Valid PPG reading
        let validReading = PPGReading(red: 1000, ir: 1500)
        
        // When & Then
        XCTAssertTrue(parser.validatePPGReading(validReading))
        
        // Given: Invalid PPG reading (negative values)
        let invalidReading = PPGReading(red: -100, ir: 1500)
        
        // When & Then
        XCTAssertFalse(parser.validatePPGReading(invalidReading))
    }
    
    func testAccelerometerReadingValidation() {
        // Given: Any accelerometer reading (Int16 range is always valid)
        let reading = AccelerometerReading(x: 1000, y: -1000, z: 0)
        
        // When & Then
        XCTAssertTrue(parser.validateAccelerometerReading(reading))
    }
} 