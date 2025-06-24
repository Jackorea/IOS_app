# LinkBandDemo ViewModels 기능 가이드

LinkBandDemo 앱의 ViewModel을 통한 Bluetooth 디바이스 제어 및 센서 데이터 관리

## 설정 가이드

### Xcode에서 추가

#### 링크밴드 SDK 추가
1. File → Add Package Dependencies...
2. 레포지토리 URL 입력 (https://github.com/Jackorea/test_spm.git)
3. Add Package 누르기
4. [프로젝트명] → Targets → [프로젝트명] → General → Frameworks, Libraries, and Embedded Content
5. "+" 선택 → BluetoothKit Package → BluetoothKit 선택 → Add 누르기

#### 블루투스 권한 설정
1. [프로젝트명] → Targets → [프로젝트명] → Info → Custom iOS Target Properties 
2. "+" 선택후 아래 키 추가
   - Privacy - Bluetooth Always Usage Description
   - Privacy - Bluetooth Peripheral Usage Description

## Overview

이 문서는 LinkBandDemo 앱에서 Bluetooth 디바이스와 상호작용하기 위한 핵심 기능들을 설명합니다. 
모든 기능은 ``BluetoothKitViewModel``을 통해 제공되며, UI와 SDK 사이의 어댑터 역할을 합니다.

## 핵심 기능

### 1. Bluetooth 스캔 관리
- ``BluetoothKitViewModel/startScanning()`` - Bluetooth 디바이스 스캔 시작
- ``BluetoothKitViewModel/stopScanning()`` - Bluetooth 디바이스 스캔 중지
- ``BluetoothKitViewModel/isScanning`` - 현재 스캔 상태 확인

### 2. 디바이스 목록 관리  
- ``BluetoothKitViewModel/discoveredDevices`` - 스캔으로 발견된 디바이스 목록
- ``DeviceInfo`` - Bluetooth 디바이스 정보 구조체

### 3. 디바이스 연결 관리
- ``BluetoothKitViewModel/connect(to:)`` - 특정 디바이스에 연결
- ``BluetoothKitViewModel/disconnect()`` - 현재 연결된 디바이스에서 연결 해제
- ``BluetoothKitViewModel/connectionState`` - 현재 연결 상태
- ``BluetoothKitViewModel/isConnected`` - 연결 상태 확인
- ``DeviceConnectionState`` - 연결 상태 열거형

### 4. 센서 데이터 수신 관리
- ``BluetoothKitViewModel/enableMonitoring()`` - 센서 모니터링 시작 (실시간 데이터 수신)
- ``BluetoothKitViewModel/disableMonitoring()`` - 센서 모니터링 중지
- ``BluetoothKitViewModel/latestEEGReading`` - 최신 EEG 데이터
- ``BluetoothKitViewModel/latestPPGReading`` - 최신 PPG 데이터  
- ``BluetoothKitViewModel/latestAccelerometerReading`` - 최신 가속도계 데이터
- ``BluetoothKitViewModel/latestBatteryReading`` - 최신 배터리 데이터

### 5. 데이터 기록 및 저장
- ``BluetoothKitViewModel/startRecording()`` - CSV 파일로 센서 데이터 기록 시작
- ``BluetoothKitViewModel/stopRecording()`` - 센서 데이터 기록 중지
- ``BluetoothKitViewModel/recordingsDirectory`` - 기록 파일이 저장되는 디렉토리
- ``BluetoothKitViewModel/recordedFiles`` - 기록된 파일 목록
- ``BluetoothKitViewModel/isRecording`` - 현재 기록 상태 확인

## 코드 예시

### 기본 ViewModel 설정

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var bluetoothKitViewModel = BluetoothKitViewModel()
    
    var body: some View {
        VStack {
            // UI 구성
        }
    }
}
```

### 1. Bluetooth 스캔 구현 예시

```swift
struct ScanControlView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            if bluetoothKit.isScanning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                Button("스캔 중지") {
                    bluetoothKit.stopScanning()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button("스캔 시작") {
                    bluetoothKit.startScanning()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
    }
}
```

### 2. 디바이스 목록 표시 및 연결

```swift
struct DeviceListView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        if !bluetoothKit.discoveredDevices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("발견된 디바이스")
                    .font(.headline)
                
                ForEach(bluetoothKit.discoveredDevices, id: \.id) { device in
                    DeviceRow(device: device, bluetoothKit: bluetoothKit)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: DeviceInfo
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        HStack {
            Text(device.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Button("연결") {
                bluetoothKit.connect(to: device)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}
```

### 3. 센서 데이터 수신 표시

```swift
struct SensorDataView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // EEG 데이터 표시
            if let eegReading = bluetoothKit.latestEEGReading {
                EEGDataCard(reading: eegReading)
            }
            
            // PPG 데이터 표시
            if let ppgReading = bluetoothKit.latestPPGReading {
                PPGDataCard(reading: ppgReading)
            }
            
            // 가속도계 데이터 표시
            if let accelReading = bluetoothKit.latestAccelerometerReading {
                AccelerometerDataCard(reading: accelReading)
            }
            
            // 배터리 데이터 표시
            if let batteryReading = bluetoothKit.latestBatteryReading {
                BatteryDataCard(reading: batteryReading)
            }
        }
    }
}

struct EEGDataCard: View {
    let reading: EEGData
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("EEG 데이터")
                    .font(.headline)
                Spacer()
                Image(systemName: reading.leadOff ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(reading.leadOff ? .red : .green)
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("CH1")
                        .font(.caption)
                    Text(String(format: "%.1f µV", reading.channel1))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("CH2")
                        .font(.caption)
                    Text(String(format: "%.1f µV", reading.channel2))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("접촉 상태")
                        .font(.caption)
                    Text(reading.leadOff ? "접촉 안됨" : "접촉됨")
                        .font(.caption)
                        .foregroundColor(reading.leadOff ? .red : .green)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
}
```

### 4. 센서 모니터링 제어

```swift
struct MonitoringControlView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        HStack {
            Button("모니터링 시작") {
                bluetoothKit.enableMonitoring()
            }
            .disabled(!bluetoothKit.isConnected)
            
            Button("모니터링 중지") {
                bluetoothKit.disableMonitoring()
            }
            .disabled(!bluetoothKit.isConnected)
        }
        .buttonStyle(.bordered)
    }
}
```

### 5. 데이터 기록 (CSV 저장) 구현

```swift
struct RecordingControlView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: bluetoothKit.isRecording ? "stop.circle.fill" : "record.circle")
                    .foregroundColor(bluetoothKit.isRecording ? .red : .blue)
                    .font(.title2)
                
                Text(bluetoothKit.isRecording ? "기록 중지" : "기록 시작")
                    .font(.headline)
                    .foregroundColor(bluetoothKit.isRecording ? .red : .blue)
                
                Spacer()
                
                if bluetoothKit.isRecording {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.red)
                        .symbolEffect(.pulse)
                }
            }
            
            Button(action: {
                if bluetoothKit.isRecording {
                    bluetoothKit.stopRecording()
                } else {
                    bluetoothKit.startRecording()
                }
            }) {
                Text(bluetoothKit.isRecording ? "중지" : "시작")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bluetoothKit.isRecording ? Color.red : Color.blue)
                    .cornerRadius(8)
            }
            .disabled(!bluetoothKit.isConnected)
            
            // 기록 파일 디렉토리 표시
            if bluetoothKit.isRecording {
                Text("저장 위치: \(bluetoothKit.recordingsDirectory.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            Color(bluetoothKit.isRecording ? .red : .blue)
                .opacity(0.1)
        )
        .cornerRadius(12)
    }
}
```

### 6. 연결 상태 모니터링

```swift
struct ConnectionStatusView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        HStack {
            Image(systemName: connectionIcon)
                .foregroundColor(connectionColor)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text("연결 상태")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(bluetoothKit.connectionStatusDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            if bluetoothKit.isConnected {
                Button("연결 해제") {
                    bluetoothKit.disconnect()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var connectionIcon: String {
        switch bluetoothKit.connectionState {
        case .disconnected: return "wave.3.right.circle"
        case .scanning: return "magnifyingglass.circle"
        case .connecting: return "arrow.triangle.2.circlepath.circle"
        case .connected: return "wave.3.right.circle.fill"
        case .reconnecting: return "arrow.clockwise.circle"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    private var connectionColor: Color {
        switch bluetoothKit.connectionState {
        case .disconnected: return .gray
        case .scanning: return .blue
        case .connecting, .reconnecting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
}
```

## 데이터 타입

### 센서 데이터 구조체
- ``EEGData`` - EEG (뇌전도) 센서 데이터
- ``PPGData`` - PPG (광전 용적 맥파) 센서 데이터
- ``AccelerometerData`` - 가속도계 센서 데이터
- ``BatteryData`` - 배터리 레벨 데이터

### 설정 및 상태 타입
- ``SensorKind`` - 센서 타입 열거형
- ``AccelMode`` - 가속도계 모드 (원시값/움직임)

## 사용 예시

### 기본 워크플로우
1. **스캔 시작**: `viewModel.startScanning()`
2. **디바이스 목록 확인**: `viewModel.discoveredDevices`
3. **디바이스 연결**: `viewModel.connect(to: selectedDevice)`
4. **센서 모니터링 시작**: `viewModel.enableMonitoring()`
5. **데이터 기록 시작**: `viewModel.startRecording()`
6. **기록 중지**: `viewModel.stopRecording()`
7. **모니터링 중지**: `viewModel.disableMonitoring()`
8. **연결 해제**: `viewModel.disconnect()`

### 완전한 예시 - 간단한 센서 앱

```swift
import SwiftUI

struct SimpleSensorApp: View {
    @StateObject private var bluetoothKit = BluetoothKitViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // 연결 상태
            ConnectionStatusView(bluetoothKit: bluetoothKit)
            
            // 스캔 및 디바이스 선택
            if !bluetoothKit.isConnected {
                ScanControlView(bluetoothKit: bluetoothKit)
                DeviceListView(bluetoothKit: bluetoothKit)
            }
            
            // 연결된 경우 센서 데이터 및 제어
            if bluetoothKit.isConnected {
                MonitoringControlView(bluetoothKit: bluetoothKit)
                RecordingControlView(bluetoothKit: bluetoothKit)
                SensorDataView(bluetoothKit: bluetoothKit)
            }
        }
        .padding()
    }
}
```

### 고급 설정
배치 데이터 수집 설정은 ``BatchDataConfigurationViewModel``을 통해 관리됩니다:
- ``BatchDataConfigurationViewModel`` - 배치 데이터 수집 설정 관리
- ``CollectionModeKind`` - 데이터 수집 모드 (샘플 수/시간 기반)

## Topics

### Bluetooth 연결 관리
- ``BluetoothKitViewModel``
- ``DeviceInfo``
- ``DeviceConnectionState``

### 센서 데이터 수신
- ``EEGData``
- ``PPGData`` 
- ``AccelerometerData``
- ``BatteryData``
- ``SensorKind``

### 데이터 기록 및 저장
- CSV 파일 저장 기능
- 실시간 모니터링
- 배치 데이터 수집

### 고급 설정
- ``BatchDataConfigurationViewModel``
- ``CollectionModeKind``
- ``AccelMode``
