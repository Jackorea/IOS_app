# BluetoothKit SDK

A comprehensive, platform-agnostic Bluetooth Low Energy (BLE) SDK for connecting to sensor devices and collecting biomedical data.

## 🎯 Pure SDK Design

BluetoothKit is designed as a **pure data/logic SDK** without any UI dependencies. This allows for:

- **Framework independence**: No SwiftUI or UIKit dependencies
- **Platform flexibility**: Works on iOS, macOS, and other Apple platforms  
- **Custom UI integration**: Build your own UI components using the provided data
- **Clean architecture**: Separation of concerns between data logic and presentation

## ✨ Features

- **Real-time sensor data**: EEG, PPG, Accelerometer, Battery monitoring
- **Batch data collection**: Configure time-based or sample-count-based batch collection
- **Delegate-based callbacks**: Receive data as it arrives from connected devices
- **Automatic data recording**: Save sensor data to CSV files
- **Connection management**: Auto-reconnection and state monitoring
- **Device discovery**: Scan and filter Bluetooth devices
- **Configuration flexibility**: Customizable sample rates and device settings

## 🚀 Quick Start

### 1. Basic Real-time Usage

```swift
import BluetoothKit

class SensorDataHandler: BluetoothKitDelegate {
    func bluetoothKit(_ kit: BluetoothKit, didReceiveEEGReading reading: EEGReading) {
        print("EEG: CH1=\(reading.channel1)µV, CH2=\(reading.channel2)µV")
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didReceivePPGReading reading: PPGReading) {
        print("PPG: Red=\(reading.red), IR=\(reading.ir)")
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didUpdateConnectionState state: ConnectionState) {
        print("Connection state: \(state.description)")
    }
    
    func bluetoothKit(_ kit: BluetoothKit, didDiscoverDevice device: BluetoothDevice) {
        print("Found device: \(device.name)")
    }
    
    // Implement other delegate methods as needed...
}

// Setup
let handler = SensorDataHandler()
let bluetoothKit = BluetoothKit()
bluetoothKit.delegate = handler

// Start scanning for devices
bluetoothKit.startScanning()

// Connect to a device (from discovered devices)
if let device = bluetoothKit.discoveredDevices.first {
    bluetoothKit.connect(to: device)
}
```

### 2. Batch Data Collection

```swift
import BluetoothKit

class BatchDataHandler: SensorBatchDataDelegate {
    func didReceiveEEGBatch(_ readings: [EEGReading]) {
        print("Received EEG batch with \(readings.count) samples")
        // Process batch for FFT, filtering, etc.
        processEEGBatch(readings)
    }
    
    func didReceivePPGBatch(_ readings: [PPGReading]) {
        print("Received PPG batch with \(readings.count) samples")
        // Calculate heart rate from batch
        calculateHeartRate(from: readings)
    }
    
    func didReceiveAccelerometerBatch(_ readings: [AccelerometerReading]) {
        print("Received accelerometer batch with \(readings.count) samples")
        // Analyze motion patterns
        analyzeMotion(readings)
    }
    
    func didReceiveBatteryUpdate(_ reading: BatteryReading) {
        print("Battery level: \(reading.level)%")
    }
}

// Setup batch collection
let batchHandler = BatchDataHandler()
let bluetoothKit = BluetoothKit()
bluetoothKit.batchDataDelegate = batchHandler

// Configure batch collection
// Time-based: collect every 0.5 seconds
bluetoothKit.setDataCollection(timeInterval: 0.5, for: .eeg)

// Sample-count-based: collect every 25 samples
bluetoothKit.setDataCollection(sampleCount: 25, for: .ppg)

// Disable specific sensor collection
bluetoothKit.disableDataCollection(for: .accelerometer)

// Disable all batch collection
bluetoothKit.disableAllDataCollection()
```

### 3. SwiftUI Integration

```swift
import SwiftUI
import BluetoothKit

struct ContentView: View {
    @StateObject private var bluetoothKit = BluetoothKit()
    @StateObject private var dataHandler = SensorDataHandler()
    
    var body: some View {
        VStack {
            Text("Connection: \(bluetoothKit.connectionState.description)")
            
            Button("Start Scanning") {
                bluetoothKit.startScanning()
            }
            
            List(bluetoothKit.discoveredDevices, id: \.id) { device in
                Button("Connect to \(device.name)") {
                    bluetoothKit.connect(to: device)
                }
            }
        }
        .onAppear {
            bluetoothKit.delegate = dataHandler
        }
    }
}
```

### 4. Custom Configuration

```swift
let config = SensorConfiguration(
    eegSampleRate: 500.0,
    ppgSampleRate: 100.0,
    deviceNamePrefix: "MyDevice-",
    autoReconnectEnabled: true
)

let bluetoothKit = BluetoothKit(configuration: config)
```

## 📱 UI Components (Separate from SDK)

The main app includes example UI components that work with the BluetoothKit SDK:

- `EnhancedStatusCardView`: Complete connection status and control interface
- `BatchDataCollectionView`: Configure and monitor batch data collection
- `BatchDataStatsView`: Real-time statistics for batch data reception
- `DataRateIndicator`: Visual indicators for sensor data reception

These are provided as examples - you can build your own UI components using the SDK's published properties and delegate callbacks.

## 🔧 Architecture

```
BluetoothKit SDK (Pure Logic)
├── BluetoothKit.swift          # Main SDK interface
├── BluetoothManager.swift      # Bluetooth connectivity
├── Models.swift               # Data models & protocols
├── DataRecorder.swift         # CSV data recording
└── SensorDataParser.swift     # Raw data parsing

Personal App (UI Layer)
├── Views/StatusCard/          # UI components
├── Views/Controls/            # Batch collection controls
├── Views/SensorData/          # Data visualization
├── ContentView.swift          # Main app view
└── personalApp.swift         # App entry point
```

## 📊 Data Types

### EEG Reading
```swift
struct EEGReading {
    let channel1: Double    // µV
    let channel2: Double    // µV  
    let leadOff: Bool      // Connection status
    let timestamp: Date
}
```

### PPG Reading
```swift
struct PPGReading {
    let red: Int           // Red LED value
    let ir: Int            // Infrared LED value
    let timestamp: Date
}
```

### Accelerometer Reading
```swift
struct AccelerometerReading {
    let x: Int16           // X-axis
    let y: Int16           // Y-axis
    let z: Int16           // Z-axis
    let timestamp: Date
}
```

### Battery Reading
```swift
struct BatteryReading {
    let level: UInt8       // 0-100%
    let timestamp: Date
}
```

## 🎛️ Batch Data Collection API

The SDK provides powerful batch data collection capabilities:

### Setting Up Batch Collection

```swift
// Time-based collection (recommended for consistent intervals)
bluetoothKit.setDataCollection(timeInterval: 1.0, for: .eeg)  // Every 1 second
bluetoothKit.setDataCollection(timeInterval: 0.5, for: .ppg)  // Every 0.5 seconds

// Sample-count-based collection (recommended for exact sample sizes)
bluetoothKit.setDataCollection(sampleCount: 250, for: .eeg)        // Every 250 samples
bluetoothKit.setDataCollection(sampleCount: 50, for: .ppg)         // Every 50 samples
bluetoothKit.setDataCollection(sampleCount: 30, for: .accelerometer) // Every 30 samples
```

### Batch Collection Limits

- **Time intervals**: 0.04 seconds (25ms) to 10.0 seconds
- **Sample counts**: 1 to sensor-specific maximums
  - EEG: up to 2500 samples (10 seconds at 250Hz)
  - PPG: up to 500 samples (10 seconds at 50Hz)  
  - Accelerometer: up to 300 samples (10 seconds at 30Hz)

### Use Cases

- **Real-time monitoring**: 0.1-0.5 second intervals for live feedback
- **Signal analysis**: 1-2 second intervals for FFT and filtering
- **Battery optimization**: 5-10 second intervals for longer operation
- **Exact sample processing**: Use sample counts for algorithms requiring specific buffer sizes

## 🔗 Delegate Protocols

### Real-time Data Delegate

Implement `BluetoothKitDelegate` to receive individual data points:

```swift
protocol BluetoothKitDelegate: AnyObject {
    func bluetoothKit(_ kit: BluetoothKit, didReceiveEEGReading reading: EEGReading)
    func bluetoothKit(_ kit: BluetoothKit, didReceivePPGReading reading: PPGReading)
    func bluetoothKit(_ kit: BluetoothKit, didReceiveAccelerometerReading reading: AccelerometerReading)
    func bluetoothKit(_ kit: BluetoothKit, didReceiveBatteryReading reading: BatteryReading)
    func bluetoothKit(_ kit: BluetoothKit, didUpdateConnectionState state: ConnectionState)
    func bluetoothKit(_ kit: BluetoothKit, didDiscoverDevice device: BluetoothDevice)
}
```

### Batch Data Delegate

Implement `SensorBatchDataDelegate` to receive data in batches:

```swift
protocol SensorBatchDataDelegate: AnyObject {
    func didReceiveEEGBatch(_ readings: [EEGReading])
    func didReceivePPGBatch(_ readings: [PPGReading])
    func didReceiveAccelerometerBatch(_ readings: [AccelerometerReading])
    func didReceiveBatteryUpdate(_ reading: BatteryReading)  // Individual updates only
}
```

## 🎛️ Configuration Options

```swift
struct SensorConfiguration {
    let eegSampleRate: Double              // Hz (125, 250, 500, 1000)
    let ppgSampleRate: Double              // Hz (25, 50, 100)
    let accelerometerSampleRate: Double    // Hz (10, 30, 50, 100)
    let deviceNamePrefix: String           // Device filter
    let autoReconnectEnabled: Bool         // Auto-reconnection
    let eegVoltageReference: Double        // Volts (2.5, 3.3, 5.0)
    let eegGain: Double                   // Amplification (1, 2, 4, 6, 8, 12, 24)
}
```

## 📝 Data Recording

```swift
// Start recording (automatic CSV file creation)
bluetoothKit.startRecording()

// Stop recording
bluetoothKit.stopRecording()

// Access recorded files
let files = bluetoothKit.recordedFiles
for file in files {
    print("Recorded: \(file.lastPathComponent)")
}
```

## 🛠️ Development

### Requirements
- iOS 13.0+ / macOS 10.15+
- Xcode 15.0+
- Swift 6.0+

### Building
```bash
# Clone the repository
git clone <repository-url>
cd personal

# Open in Xcode
open personal.xcodeproj

# Or build via command line
xcodebuild -project personal.xcodeproj -scheme personal build
```

## 📚 Examples

Check the `personal` app for complete implementation examples:
- Real-time sensor data visualization
- Connection management UI
- Data recording and playback
- Custom sensor configurations

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Make changes to the **BluetoothKit SDK only** (no UI dependencies)
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

[Your License Here] 