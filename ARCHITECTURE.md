# 🏗️ LinkBand iOS Demo App - 아키텍처 가이드

## 📋 목차

1. [전체 아키텍처 개요](#전체-아키텍처-개요)
2. [SDK (BluetoothKit) 구조](#sdk-bluetoothkit-구조)
3. [앱 (personal) 구조](#앱-personal-구조)
4. [MVVM 패턴 구현](#mvvm-패턴-구현)
5. [데이터 흐름](#데이터-흐름)
6. [책임 분리 원칙](#책임-분리-원칙)
7. [확장 가이드](#확장-가이드)

## 전체 아키텍처 개요

### 🎯 설계 목표

- **명확한 책임 분리**: SDK는 BLE 통신과 데이터 처리, 앱은 UI와 사용자 상호작용
- **재사용 가능한 SDK**: UI 독립적인 순수 데이터/로직 SDK
- **유지보수성**: MVVM 패턴으로 테스트 가능하고 확장 가능한 구조
- **확장성**: 새로운 센서나 기능 추가가 용이한 구조

### 🏗️ 전체 구조

```
IOS_link_band_demo_app/
├── 🔧 BluetoothKit/                    # SDK 모듈
│   ├── BluetoothKit.swift              # 메인 SDK 인터페이스
│   ├── BluetoothManager.swift          # BLE 통신 관리자
│   ├── DataRecorder.swift              # 데이터 기록 관리자
│   ├── SensorDataParser.swift          # 센서 데이터 파서
│   └── Models.swift                    # 데이터 모델 및 유틸리티
│
└── 📱 personal/                        # 데모 앱
    ├── personalApp.swift               # 앱 진입점
    ├── ContentView.swift               # 메인 뷰
    │
    ├── 🎭 ViewModels/                  # MVVM ViewModels
    │   └── BatchDataConfigurationViewModel.swift
    │
    └── 🎨 Views/                       # UI 컴포넌트들
        ├── Controls/                   # 컨트롤 UI
        │   ├── SimplifiedBatchDataCollectionView.swift
        │   ├── RecordingControlsView.swift
        │   └── ControlsView.swift
        ├── Files/                      # 파일 관리 UI
        ├── SensorData/                 # 센서 데이터 표시 UI
        └── StatusCard/                 # 상태 카드 UI
```

## SDK (BluetoothKit) 구조

### 🔧 핵심 구성요소

#### 1. BluetoothKit.swift
**역할**: SDK의 메인 인터페이스
```swift
public class BluetoothKit: ObservableObject {
    // 공개 API
    public func startScanning()
    public func connect(to device: BluetoothDevice)
    public func startRecording()
    public func configureBatchDataCollection(config: BatchDataCollectionConfig)
    
    // 델리게이트들
    public weak var eegDataDelegate: EEGDataDelegate?
    public weak var batchDataDelegate: SensorBatchDataDelegate?
    
    // 상태 관리
    @Published public private(set) var isConnected = false
    @Published public private(set) var isRecording = false
}
```

#### 2. BluetoothManager.swift
**역할**: 저수준 BLE 통신
- CBCentralManager 래핑
- 디바이스 스캐닝 및 연결
- 특성(Characteristic) 읽기/쓰기
- 자동 재연결 로직

#### 3. DataRecorder.swift
**역할**: 센서 데이터 기록
- CSV 파일 생성 및 관리
- 선택적 센서 데이터 기록
- 파일 시스템 관리

#### 4. SensorDataParser.swift
**역할**: 원시 BLE 데이터 파싱
- 바이트 배열을 구조체로 변환
- 센서별 데이터 포맷 처리
- 데이터 검증 및 오류 처리

#### 5. Models.swift
**역할**: 데이터 모델 및 유틸리티
```swift
// 데이터 모델들
public struct EEGReading: Sendable { ... }
public struct PPGReading: Sendable { ... }
public struct AccelerometerReading: Sendable { ... }

// 유틸리티 클래스
public class BatchDataConsoleLogger: SensorBatchDataDelegate { ... }

// 설정 구조체
public struct BatchDataCollectionConfig { ... }
```

### 📡 SDK 델리게이트 패턴

```swift
// 실시간 데이터 수신
public protocol EEGDataDelegate: AnyObject {
    func didReceiveEEGReading(_ reading: EEGReading)
}

// 배치 데이터 수신
public protocol SensorBatchDataDelegate: AnyObject {
    func didReceiveEEGBatch(_ readings: [EEGReading])
    func didReceivePPGBatch(_ readings: [PPGReading])
    func didReceiveAccelerometerBatch(_ readings: [AccelerometerReading])
}
```

## 앱 (personal) 구조

### 📱 MVVM 구조

#### 1. Models
- SDK의 데이터 모델 직접 사용
- 앱별 추가 모델은 최소화

#### 2. Views (UI Layer)
**특징**: 순수 SwiftUI 컴포넌트
- 비즈니스 로직 없음
- ViewModel과의 바인딩만 처리
- 재사용 가능한 컴포넌트들

**주요 View들**:
- `SimplifiedBatchDataCollectionView`: 배치 데이터 수집 설정 UI
- `RecordingControlsView`: 기록 컨트롤 UI
- `SensorDataView`: 실시간 센서 데이터 표시

#### 3. ViewModels (Presentation Logic)
**특징**: UI 상태 관리 및 SDK 통신
- `@Published` 속성으로 UI 상태 관리
- SDK와의 최소한의 통신 인터페이스
- 입력 검증 및 비즈니스 로직

### 📋 ViewModel 상세 구조

#### BatchDataConfigurationViewModel
```swift
@MainActor
class BatchDataConfigurationViewModel: ObservableObject {
    // MARK: - UI 상태
    @Published var selectedSensors: Set<SensorTypeOption>
    @Published var isConfigured = false
    @Published var showValidationError = false
    
    // MARK: - SDK 통신
    private let bluetoothKit: BluetoothKit
    private var consoleLogger: BatchDataConsoleLogger?
    
    // MARK: - 공개 인터페이스
    func applyInitialConfiguration()
    func removeConfiguration()
    func updateSensorSelection(_ sensors: Set<SensorTypeOption>)
    func validateSampleCount(_ text: String, for sensor: SensorTypeOption) -> Bool
    
    // MARK: - 내부 로직
    private func setupConsoleLogger()
    private func configureSelectedSensors()
    private func scheduleConfigurationUpdate()
}
```

## MVVM 패턴 구현

### 🔄 데이터 바인딩

#### View → ViewModel
```swift
struct SimplifiedBatchDataCollectionView: View {
    @StateObject private var viewModel: BatchDataConfigurationViewModel
    
    var body: some View {
        // UI 이벤트를 ViewModel 메서드로 전달
        Button("설정 적용") {
            viewModel.applyInitialConfiguration()
        }
        
        // 사용자 입력을 ViewModel로 전달
        TextField("샘플 수", text: $viewModel.eegSampleCountText)
            .onChange(of: viewModel.eegSampleCountText) { newValue in
                viewModel.validateSampleCount(newValue, for: .eeg)
            }
    }
}
```

#### ViewModel → View
```swift
class BatchDataConfigurationViewModel: ObservableObject {
    // UI 상태 변경 시 자동으로 View 업데이트
    @Published var selectedSensors: Set<SensorTypeOption> = [.eeg, .ppg]
    @Published var showValidationError: Bool = false
    @Published var validationMessage: String = ""
}
```

#### ViewModel → SDK
```swift
class BatchDataConfigurationViewModel: ObservableObject {
    private let bluetoothKit: BluetoothKit
    
    func applyInitialConfiguration() {
        // 1. UI 상태 준비
        setupConsoleLogger()
        
        // 2. SDK 호출
        configureSelectedSensors()
        
        // 3. UI 상태 업데이트
        isConfigured = true
    }
    
    private func configureSelectedSensors() {
        for sensorOption in allSensorTypes {
            if selectedSensors.contains(sensorOption) {
                let config = BatchDataCollectionConfig(
                    sensorType: sensorOption.sdkType,
                    targetSampleCount: getSampleCount(for: sensorOption)
                )
                bluetoothKit.configureBatchDataCollection(config: config)
            }
        }
    }
}
```

## 데이터 흐름

### 📡 실시간 데이터 흐름

```
BLE Device → BluetoothManager → SensorDataParser → BluetoothKit → View
                                                              ┌─────────┐
                                                              │ Delegate│
                                                              │Callbacks│
                                                              └─────────┘
```

### 📊 배치 데이터 흐름

```
BLE Device → BluetoothManager → SensorDataParser → BluetoothKit → BatchDataDelegate
                                                                 ┌──────────────────┐
                                                                 │BatchDataConsole  │
                                                                 │Logger (SDK 유틸) │
                                                                 └──────────────────┘
```

### 🎛️ UI 상호작용 흐름

```
User Input → View → ViewModel → SDK API → BLE Device
                     │
                     ├─ UI State Update
                     ├─ Validation
                     └─ Business Logic
```

## 책임 분리 원칙

### 🔧 SDK 책임 (BluetoothKit)

**해야 할 것**:
- ✅ BLE 통신 관리
- ✅ 센서 데이터 파싱
- ✅ 데이터 기록 (CSV)
- ✅ 연결 상태 관리
- ✅ 자동 재연결
- ✅ 델리게이트 콜백
- ✅ 유틸리티 클래스 제공

**하지 말아야 할 것**:
- ❌ UI 로직
- ❌ SwiftUI 의존성
- ❌ 앱별 비즈니스 로직
- ❌ 사용자 설정 저장
- ❌ 네비게이션 로직

### 📱 앱 책임 (personal)

**해야 할 것**:
- ✅ 사용자 인터페이스
- ✅ 사용자 상호작용 처리
- ✅ 앱별 비즈니스 로직
- ✅ 입력 검증
- ✅ 상태 관리 (UI 레벨)
- ✅ 네비게이션

**하지 말아야 할 것**:
- ❌ BLE 통신 로직
- ❌ 센서 데이터 파싱
- ❌ 저수준 디바이스 제어
- ❌ SDK 내부 구현

## 확장 가이드

### 🔧 SDK 확장

#### 새로운 센서 타입 추가

1. **Models.swift**에 새 데이터 구조체 추가:
```swift
public struct NewSensorReading: Sendable {
    public let value: Double
    public let timestamp: Date
    
    public init(value: Double, timestamp: Date = Date()) {
        self.value = value
        self.timestamp = timestamp
    }
}
```

2. **SensorType** enum 확장:
```swift
public enum SensorType: String, CaseIterable {
    case eeg = "EEG"
    case ppg = "PPG"  
    case accelerometer = "ACC"
    case newSensor = "NEW"  // 추가
    
    public var sampleRate: Double {
        switch self {
        case .newSensor: return 100.0  // 추가
        default: return existingRates
        }
    }
}
```

3. **SensorDataParser.swift**에 파싱 로직 추가
4. **BluetoothKit.swift**에 델리게이트 및 메서드 추가

### 📱 앱 확장

#### 새로운 화면 추가

1. **Views/** 하위에 새 SwiftUI View 생성
2. 필요시 **ViewModels/**에 새 ViewModel 생성:
```swift
@MainActor
class NewFeatureViewModel: ObservableObject {
    @Published var uiState: SomeState
    private let bluetoothKit: BluetoothKit
    
    init(bluetoothKit: BluetoothKit) {
        self.bluetoothKit = bluetoothKit
    }
    
    func performAction() {
        // 앱 로직 처리 후 SDK 호출
        bluetoothKit.someSDKMethod()
    }
}
```

3. **ContentView.swift**에 새 View 통합

#### ViewModel을 통한 SDK 통신 패턴

```swift
class ExampleViewModel: ObservableObject {
    // 1. UI 상태 선언
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 2. SDK 참조 (private)
    private let bluetoothKit: BluetoothKit
    
    // 3. 공개 메서드에서 상태 관리 + SDK 호출
    func performAction() {
        isLoading = true
        errorMessage = nil
        
        // SDK 호출
        bluetoothKit.someMethod { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    // 성공 처리
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

## 🎯 핵심 원칙 요약

1. **단일 책임**: 각 클래스와 모듈은 하나의 명확한 책임을 가짐
2. **의존성 역전**: 고수준 모듈(앱)이 저수준 모듈(SDK)에 의존하지만, 인터페이스를 통해 결합도 최소화
3. **개방-폐쇄**: 새로운 기능 추가는 가능하되, 기존 코드 수정은 최소화
4. **인터페이스 분리**: 클라이언트는 사용하지 않는 인터페이스에 의존하지 않음
5. **DRY (Don't Repeat Yourself)**: 코드 중복 최소화 및 재사용성 극대화

---

**이 아키텍처를 통해 유지보수 가능하고 확장 가능한 iOS 앱을 구축할 수 있습니다.** 