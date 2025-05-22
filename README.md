# MyBluetoothLibrary (가칭)

간단하고 사용하기 쉬운 Swift용 Bluetooth Low Energy (BLE) 라이브러리입니다. 특정 센서 장치와의 통신, 데이터 스캔, 연결, 데이터 수신 및 기본 처리를 목적으로 합니다. SwiftUI와 함께 사용하기 용이하도록 `ObservableObject`를 활용합니다.

## 주요 기능

*   Bluetooth 장치 스캔 (특정 접두사 "LXB-"를 가진 장치 필터링)
*   장치 연결 및 연결 해제
*   자동 재연결 기능 (활성화/비활성화 가능)
*   센서 데이터 수신 및 기본 처리:
    *   EEG (뇌파)
    *   PPG (광혈류측정)
    *   Accelerometer (가속도계)
    *   Battery Level (배터리 잔량)
*   SwiftUI와 손쉬운 통합을 위한 `@Published` 프로퍼티 제공

## 설정

1.  **라이브러리 추가**: `MyBluetoothLibrary`의 소스 파일들(`BluetoothViewModel.swift`, `BluetoothDevice.swift`, `SensorUUID.swift`)을 당신의 Xcode 프로젝트에 추가하고, 사용하고자 하는 타겟의 멤버로 설정해주세요. (향후 Swift Package Manager 등을 지원할 수 있습니다.)
2.  **Info.plist 설정**: Bluetooth 통신을 위해 앱의 `Info.plist` 파일에 다음 권한 설명을 추가해야 합니다:
    *   `NSBluetoothAlwaysUsageDescription`: (iOS 13 이상) 앱이 백그라운드에서도 Bluetooth를 사용해야 하는 경우.
    *   `NSBluetoothPeripheralUsageDescription`: (iOS 12 이하 또는 백그라운드 사용이 필요 없을 때) 앱이 Bluetooth 주변 장치와 통신해야 하는 이유.
    *   예: `<key>NSBluetoothAlwaysUsageDescription</key><string>센서 장치와 연결하여 데이터를 수신합니다.</string>`

## 핵심 컴포넌트: `BluetoothViewModel`

라이브러리와 상호작용하기 위한 주요 클래스입니다. `NSObject`를 상속하고 `ObservableObject` 프로토콜을 채택하여 SwiftUI 뷰에서 상태 변화를 쉽게 감지하고 UI를 업데이트할 수 있습니다.

```swift
import SwiftUI
// import MyBluetoothLibrary // 만약 별도 모듈로 구성했다면 import 하세요.

struct YourAppView: View {
    @StateObject private var bluetoothViewModel = BluetoothViewModel()
    // ... SwiftUI 뷰 코드 ...
}
```

### 주요 Public 프로퍼티

`BluetoothViewModel`은 UI 업데이트 및 상태 확인을 위해 다음과 같은 `@Published` 프로퍼티들을 제공합니다:

*   `devices: [BluetoothDevice]`: 현재까지 발견된 Bluetooth 장치 목록입니다. `BluetoothDevice`는 `Identifiable`하며 `id (UUID)`, `peripheral (CBPeripheral)`, `name (String)`을 가집니다.
*   `isScanning: Bool`: 현재 Bluetooth 장치를 스캔 중인지 여부를 나타냅니다.
*   `connectedPeripheral: CBPeripheral?`: 현재 연결된 `CBPeripheral` 객체입니다. 연결되지 않은 경우 `nil`입니다.
*   `connectionStatus: String`: "Not Connected", "Connecting to...", "Connected to...", "Disconnected" 등 사용자에게 보여줄 수 있는 연결 상태 문자열입니다.
*   `showBluetoothOffAlert: Bool`: Bluetooth가 꺼져 있을 때 `true`가 됩니다. 이를 사용하여 사용자에게 Bluetooth를 켜도록 안내하는 알림을 표시할 수 있습니다.
*   `autoReconnectEnabled: Bool`: 자동 재연결 기능의 활성화 여부를 제어합니다. 기본값은 `true`입니다.

### 주요 Public 메소드

*   `init()`: `BluetoothViewModel`의 새 인스턴스를 생성합니다.
*   `startScan()`: 주변의 Bluetooth 장치 스캔을 시작합니다.
*   `stopScan()`: 진행 중인 스캔을 중지합니다.
*   `connectToDevice(_ device: BluetoothDevice)`: 주어진 `BluetoothDevice`에 연결을 시도합니다.
*   `disconnect()`: 현재 연결된 장치와의 연결을 해제합니다.

## 사용 예제 (SwiftUI)

```swift
import SwiftUI
// import MyBluetoothLibrary // 별도 모듈일 경우

struct BluetoothDemoView: View {
    @StateObject private var bluetoothViewModel = BluetoothViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                // 상태 표시 카드
                VStack {
                    HStack {
                        Image(systemName: bluetoothViewModel.connectedPeripheral != nil ? "wave.3.right.circle.fill" : "wave.3.right.circle")
                            .foregroundColor(bluetoothViewModel.connectedPeripheral != nil ? .green : .gray)
                        Text(bluetoothViewModel.connectionStatus)
                            .font(.headline)
                    }
                    if bluetoothViewModel.isScanning {
                        ProgressView().padding(.top, 5)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground).cornerRadius(10)) // iOS 스타일 배경
                .shadow(radius: 3)

                // 제어 버튼
                HStack {
                    Button(action: { bluetoothViewModel.startScan() }) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bluetoothViewModel.isScanning)

                    if bluetoothViewModel.isScanning {
                        Button(action: { bluetoothViewModel.stopScan() }) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                if bluetoothViewModel.connectedPeripheral != nil {
                    Button(action: { bluetoothViewModel.disconnect() }) {
                        Label("Disconnect", systemImage: "link.badge.minus")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                
                Toggle("Auto Reconnect", isOn: $bluetoothViewModel.autoReconnectEnabled)
                    .padding(.horizontal)

                Text("Discovered Devices:")
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                List(bluetoothViewModel.devices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text(device.peripheral.identifier.uuidString).font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        if bluetoothViewModel.connectedPeripheral?.identifier != device.peripheral.identifier {
                            Button("Connect") {
                                bluetoothViewModel.connectToDevice(device)
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        } else {
                            Text("Connected")
                                .foregroundColor(.green)
                        }
                    }
                }
                .listStyle(.plain) // 또는 .insetGrouped
            }
            .padding()
            .navigationTitle("Bluetooth Library Demo")
            .alert("Bluetooth is Off", isPresented: $bluetoothViewModel.showBluetoothOffAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please turn on Bluetooth to connect to devices.")
            }
            // 데이터 처리 예시 (BluetoothViewModel을 확장하여 사용)
            // .onReceive(bluetoothViewModel.$eegData) { newData in
            //     // EEG 데이터 처리
            // }
        }
    }
}

// BluetoothDevice는 Identifiable 해야 하므로, BluetoothDevice.swift 파일이 프로젝트에 포함되어야 합니다.
// public struct BluetoothDevice: Identifiable {
//     public let id: UUID = UUID() // 자동 생성
//     public let peripheral: CBPeripheral
//     public let name: String
// 
//     public init(peripheral: CBPeripheral, name: String) {
//         self.peripheral = peripheral
//         self.name = name
//     }
// }

// SensorUUID도 마찬가지로 프로젝트 내에 있어야 합니다.
// public struct SensorUUID { ... }
```

## 데이터 처리

`BluetoothViewModel` 내부에는 다음과 같은 데이터 처리 메소드가 존재합니다 (현재는 `public`으로 선언되어 있으나, 라이브러리 사용자는 직접 호출하기보다는 `BluetoothViewModel`이 내부적으로 사용하고 그 결과를 `@Published` 프로퍼티를 통해 받거나, 콜백/델리게이트 패턴을 통해 받는 것이 일반적입니다):

*   `handleEEGData(_ data: Data)`
*   `handlePPGData(_ data: Data)`
*   `handleAccelData(_ data: Data)`
*   `handleBatteryData(_ data: Data)`

현재 이 메소드들은 수신된 데이터를 파싱하여 콘솔에 출력합니다. 실제 애플리케이션에서는 이 데이터를 UI에 표시하거나, 저장하거나, 추가 분석을 위해 `BluetoothViewModel` 내부에 새로운 `@Published` 프로퍼티를 만들거나, delegate/closure 콜백을 사용하여 외부로 전달하도록 수정할 수 있습니다.

### 예시: EEG 데이터 UI 표시를 위한 ViewModel 수정 (아이디어)

```swift
// BluetoothViewModel.swift 내부에 추가
// @Published public var latestEEGReading: String = "No EEG Data"
//
// public func handleEEGData(_ data: Data) {
//     // ... 기존 파싱 로직 ...
//     let formattedReading = "EEG CH1: \(ch1uV) µV, CH2: \(ch2uV) µV, LeadOff: \(leadOff)"
//     DispatchQueue.main.async {
//         self.latestEEGReading = formattedReading
//     }
//     print(formattedReading)
// }

// SwiftUI View에서 사용
// Text(bluetoothViewModel.latestEEGReading)
```

## 캡슐화 및 라이브러리 디자인

*   **`BluetoothViewModel`**: 라이브러리의 주요 인터페이스입니다. 내부 BLE 로직(Central Manager, Peripheral Delegate 등)은 이 클래스에 캡슐화되어 있습니다. 사용자는 `BluetoothViewModel`의 public 프로퍼티와 메소드를 통해서만 라이브러리 기능과 상호작용합니다.
*   **`BluetoothDevice`**: 발견된 장치를 나타내는 간단한 데이터 구조체입니다. `Identifiable`하여 SwiftUI 리스트에서 사용하기 편리합니다.
*   **`SensorUUID`**: 센서 서비스 및 특성 UUID를 정의합니다. 이는 라이브러리 내부적으로 사용되며, 사용자가 직접 접근할 필요는 거의 없습니다. (현재는 `public`으로 되어있으나, 내부 전용으로 변경 가능)
*   **상태 관리**: `@Published` 프로퍼티를 사용하여 SwiftUI 뷰가 BLE 상태 변화에 따라 자동으로 업데이트되도록 합니다.
*   **에러 처리 및 사용자 피드백**: `connectionStatus` 문자열과 `showBluetoothOffAlert` 플래그를 통해 사용자에게 현재 상태와 필요한 조치(예: Bluetooth 켜기)를 알릴 수 있습니다.

## 향후 개선 방향

*   Swift Package Manager (SPM) 지원
*   더욱 상세한 에러 처리 및 콜백 제공
*   데이터 수신을 위한 Delegate 프로토콜 또는 Closure 기반 콜백 추가
*   특정 장치 필터링 옵션 확장 (UUID, 이름 외)
*   Write Characteristic 기능 추가 (예: 장치 설정 변경)

---

이 README는 기본적인 시작점입니다. 실제 라이브러리로 배포 시에는 더욱 상세한 설치 방법, API 문서, 고급 사용 예제 등을 추가하는 것이 좋습니다. 