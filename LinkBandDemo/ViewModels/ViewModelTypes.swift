import SwiftUI
import Foundation
// BluetoothKit import 제거 - 완전한 SDK 독립성

// MARK: - ViewModel Data Types (SDK 타입 래핑)
// Views가 SDK에 의존하지 않고 어댑터만 사용할 수 있도록 모든 타입을 래핑

/// EEG (뇌전도) 센서 데이터를 래핑하는 구조체
/// SDK의 EEGReading 타입을 UI에서 안전하게 사용할 수 있도록 변환합니다.
public struct EEGData {
    /// 첫 번째 채널의 신호값
    public let channel1: Double
    /// 두 번째 채널의 신호값
    public let channel2: Double
    /// 첫 번째 채널의 원시 ADC 값
    public let ch1Raw: Int
    /// 두 번째 채널의 원시 ADC 값
    public let ch2Raw: Int
    /// 전극 연결 상태 (true: 연결 해제됨, false: 정상 연결)
    public let leadOff: Bool
    /// 데이터 수집 시각
    public let timestamp: Date
    
    /// EEGData 구조체의 이니셜라이저
    /// - Parameters:
    ///   - channel1: 첫 번째 채널 신호값
    ///   - channel2: 두 번째 채널 신호값
    ///   - ch1Raw: 첫 번째 채널 원시값
    ///   - ch2Raw: 두 번째 채널 원시값
    ///   - leadOff: 전극 연결 상태
    ///   - timestamp: 수집 시각
    public init(channel1: Double, channel2: Double, ch1Raw: Int, ch2Raw: Int, leadOff: Bool, timestamp: Date) {
        self.channel1 = channel1
        self.channel2 = channel2
        self.ch1Raw = ch1Raw
        self.ch2Raw = ch2Raw
        self.leadOff = leadOff
        self.timestamp = timestamp
    }
}

/// PPG (광전 용적 맥파) 센서 데이터를 래핑하는 구조체
/// SDK의 PPGReading 타입을 UI에서 안전하게 사용할 수 있도록 변환합니다.
public struct PPGData {
    /// 적외선 LED 신호값
    public let red: Int
    /// 근적외선 LED 신호값
    public let ir: Int
    /// 데이터 수집 시각
    public let timestamp: Date
    
    /// PPGData 구조체의 이니셜라이저
    /// - Parameters:
    ///   - red: 적외선 LED 신호값
    ///   - ir: 근적외선 LED 신호값
    ///   - timestamp: 수집 시각
    public init(red: Int, ir: Int, timestamp: Date) {
        self.red = red
        self.ir = ir
        self.timestamp = timestamp
    }
}

/// 가속도계 센서 데이터를 래핑하는 구조체
/// SDK의 AccelerometerReading 타입을 UI에서 안전하게 사용할 수 있도록 변환합니다.
public struct AccelerometerData {
    /// X축 가속도 값
    public let x: Int
    /// Y축 가속도 값
    public let y: Int
    /// Z축 가속도 값
    public let z: Int
    /// 데이터 수집 시각
    public let timestamp: Date
    
    /// AccelerometerData 구조체의 이니셜라이저
    /// - Parameters:
    ///   - x: X축 가속도 값
    ///   - y: Y축 가속도 값
    ///   - z: Z축 가속도 값
    ///   - timestamp: 수집 시각
    public init(x: Int, y: Int, z: Int, timestamp: Date) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }
}

/// 배터리 센서 데이터를 래핑하는 구조체
/// SDK의 BatteryReading 타입을 UI에서 안전하게 사용할 수 있도록 변환합니다.
public struct BatteryData {
    /// 배터리 잔량 (0-100%)
    public let level: Int
    /// 데이터 수집 시각
    public let timestamp: Date
    
    /// BatteryData 구조체의 이니셜라이저
    /// - Parameters:
    ///   - level: 배터리 잔량 (0-100%)
    ///   - timestamp: 수집 시각
    public init(level: Int, timestamp: Date) {
        self.level = level
        self.timestamp = timestamp
    }
}

/// Bluetooth 디바이스 정보를 래핑하는 구조체
/// SDK의 BluetoothDevice 타입을 UI에서 안전하게 사용할 수 있도록 변환합니다.
public struct DeviceInfo {
    /// 디바이스 고유 식별자
    public let id: UUID
    /// 디바이스 이름
    public let name: String
    
    /// DeviceInfo 구조체의 이니셜라이저
    /// - Parameters:
    ///   - id: 디바이스 고유 식별자
    ///   - name: 디바이스 이름
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// 센서 타입을 정의하는 열거형
/// SDK의 SensorType을 UI에서 안전하게 사용할 수 있도록 래핑합니다.
public enum SensorKind: String, CaseIterable {
    /// EEG (뇌전도) 센서
    case eeg = "EEG"
    /// PPG (광전 용적 맥파) 센서
    case ppg = "PPG"
    /// 가속도계 센서
    case accelerometer = "ACC"
    /// 배터리 센서
    case battery = "배터리"
    
    /// UI에서 표시될 센서 이름
    public var displayName: String { rawValue }
    
    /// 센서 타입별 이모지 아이콘
    public var emoji: String {
        switch self {
        case .eeg: return "🧠"
        case .ppg: return "❤️"
        case .accelerometer: return "📱"
        case .battery: return "🔋"
        }
    }
    
    /// 센서 타입별 색상 문자열
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

/// 디바이스 연결 상태를 정의하는 열거형
/// SDK의 ConnectionState를 UI에서 안전하게 사용할 수 있도록 래핑합니다.
public enum DeviceConnectionState {
    /// 연결 해제됨
    case disconnected
    /// 디바이스 스캔 중
    case scanning
    /// 연결 시도 중
    case connecting
    /// 연결 완료됨
    case connected
    /// 재연결 시도 중
    case reconnecting
    /// 연결 실패
    case failed
}

/// 가속도계 모드를 정의하는 열거형
/// SDK의 AccelerometerMode를 UI에서 안전하게 사용할 수 있도록 래핑합니다.
public enum AccelMode {
    /// 원시 센서 값 모드
    case raw
    /// 움직임 데이터 모드
    case motion
    
    /// 모드별 설명 문자열
    public var description: String {
        switch self {
        case .raw: return "원시 센서 값 (Raw ADC)"
        case .motion: return "움직임 데이터 (Motion)"
        }
    }
}

// MARK: - Batch Data Collection Types (SDK 래핑)

/// 배치 데이터 수집 모드를 정의하는 열거형
/// SDK의 BatchDataConfigurationManager.CollectionMode를 UI에서 안전하게 사용할 수 있도록 래핑합니다.
public enum CollectionModeKind: CaseIterable {
    /// 샘플 수 기준 수집
    case sampleCount
    /// 시간(초) 기준 수집
    case seconds
    /// 시간(분) 기준 수집
    case minutes
    
    /// UI에서 표시될 모드 이름
    public var displayName: String {
        switch self {
        case .sampleCount: return "샘플 수"
        case .seconds: return "시간 (초)"
        case .minutes: return "시간 (분)"
        }
    }
    
    // SDK 변환 메서드들은 어댑터 ViewModel에서만 internal extension으로 구현
}

/// 센서 설정 정보를 래핑하는 구조체
/// SDK의 센서 설정 데이터를 UI에서 안전하게 사용할 수 있도록 변환합니다.
public struct SensorConfigurationWrapper {
    /// 설정된 샘플 수
    public let sampleCount: Int
    /// 설정된 시간(초)
    public let seconds: Int
    /// 설정된 시간(분)
    public let minutes: Int
    /// 센서 활성화 여부
    public let isEnabled: Bool
    
    /// SensorConfigurationWrapper 구조체의 이니셜라이저
    /// - Parameters:
    ///   - sampleCount: 설정할 샘플 수
    ///   - seconds: 설정할 시간(초)
    ///   - minutes: 설정할 시간(분)
    ///   - isEnabled: 센서 활성화 여부
    public init(sampleCount: Int, seconds: Int, minutes: Int, isEnabled: Bool) {
        self.sampleCount = sampleCount
        self.seconds = seconds
        self.minutes = minutes
        self.isEnabled = isEnabled
    }
}

/// 유효성 검사 결과를 래핑하는 구조체
/// SDK의 검증 결과를 UI에서 안전하게 사용할 수 있도록 변환합니다.
public struct ValidationResultWrapper {
    /// 검증 통과 여부
    public let isValid: Bool
    /// 검증 실패 시 오류 메시지
    public let message: String?
    
    /// ValidationResultWrapper 구조체의 이니셜라이저
    /// - Parameters:
    ///   - isValid: 검증 통과 여부
    ///   - message: 오류 메시지 (검증 실패 시)
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