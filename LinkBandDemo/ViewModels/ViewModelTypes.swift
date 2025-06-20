import SwiftUI
import Foundation
// BluetoothKit import 제거 - 완전한 SDK 독립성

// MARK: - ViewModel Data Types (SDK 타입 래핑)
// Views가 SDK에 의존하지 않고 어댑터만 사용할 수 있도록 모든 타입을 래핑

/// EEG 센서 데이터 래핑 타입
public struct EEGData {
    public let channel1: Double
    public let channel2: Double
    public let ch1Raw: Int
    public let ch2Raw: Int
    public let leadOff: Bool
    public let timestamp: Date
    
    public init(channel1: Double, channel2: Double, ch1Raw: Int, ch2Raw: Int, leadOff: Bool, timestamp: Date) {
        self.channel1 = channel1
        self.channel2 = channel2
        self.ch1Raw = ch1Raw
        self.ch2Raw = ch2Raw
        self.leadOff = leadOff
        self.timestamp = timestamp
    }
}

/// PPG 센서 데이터 래핑 타입
public struct PPGData {
    public let red: Int
    public let ir: Int
    public let timestamp: Date
    
    public init(red: Int, ir: Int, timestamp: Date) {
        self.red = red
        self.ir = ir
        self.timestamp = timestamp
    }
}

/// 가속도계 센서 데이터 래핑 타입
public struct AccelerometerData {
    public let x: Int
    public let y: Int
    public let z: Int
    public let timestamp: Date
    
    public init(x: Int, y: Int, z: Int, timestamp: Date) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }
}

/// 배터리 센서 데이터 래핑 타입
public struct BatteryData {
    public let level: Int
    public let timestamp: Date
    
    public init(level: Int, timestamp: Date) {
        self.level = level
        self.timestamp = timestamp
    }
}

/// Bluetooth 디바이스 래핑 타입
public struct DeviceInfo {
    public let id: UUID
    public let name: String
    
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// 센서 타입 래핑 열거형
public enum SensorKind: String, CaseIterable {
    case eeg = "EEG"
    case ppg = "PPG"
    case accelerometer = "가속도계"
    case battery = "배터리"
    
    public var displayName: String { rawValue }
    
    public var emoji: String {
        switch self {
        case .eeg: return "🧠"
        case .ppg: return "❤️"
        case .accelerometer: return "📱"
        case .battery: return "🔋"
        }
    }
    
    public var color: String {
        switch self {
        case .eeg: return "purple"
        case .ppg: return "red"
        case .accelerometer: return "blue"
        case .battery: return "green"
        }
    }
    
    // SDK 변환 메서드들은 어댑터 ViewModel에서만 internal extension으로 구현
}

/// 연결 상태 래핑 열거형
public enum DeviceConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
    case reconnecting
    case failed
}

/// 가속도계 모드 래핑 열거형
public enum AccelMode {
    case raw
    case motion
    
    public var description: String {
        switch self {
        case .raw: return "원시 센서 값 (Raw ADC)"
        case .motion: return "움직임 데이터 (Motion)"
        }
    }
}

// MARK: - Batch Data Collection Types (SDK 래핑)

/// 배치 데이터 수집 모드 래핑 열거형
public enum CollectionModeKind: CaseIterable {
    case sampleCount
    case seconds
    case minutes
    
    public var displayName: String {
        switch self {
        case .sampleCount: return "샘플 수"
        case .seconds: return "시간 (초)"
        case .minutes: return "시간 (분)"
        }
    }
    
    // SDK 변환 메서드들은 어댑터 ViewModel에서만 internal extension으로 구현
}

/// 센서 설정 래핑 구조체
public struct SensorConfigurationWrapper {
    public let sampleCount: Int
    public let seconds: Int
    public let minutes: Int
    public let isEnabled: Bool
    
    public init(sampleCount: Int, seconds: Int, minutes: Int, isEnabled: Bool) {
        self.sampleCount = sampleCount
        self.seconds = seconds
        self.minutes = minutes
        self.isEnabled = isEnabled
    }
}

/// 유효성 검사 결과 래핑 구조체
public struct ValidationResultWrapper {
    public let isValid: Bool
    public let message: String?
    
    public init(isValid: Bool, message: String?) {
        self.isValid = isValid
        self.message = message
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - 변환 함수들은 BluetoothKitViewModel에서만 internal로 사용
// SDK 타입 변환 확장들은 BluetoothKitViewModel.swift에서 internal extension으로 구현됨 