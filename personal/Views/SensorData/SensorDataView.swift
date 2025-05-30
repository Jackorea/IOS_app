import SwiftUI
import BluetoothKit

// MARK: - Sensor Data View

struct SensorDataView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 16) {
            // EEG Data Card
            if let eegReading = bluetoothKit.latestEEGReading {
                EEGDataCard(reading: eegReading)
                    .frame(maxWidth: .infinity)
            }
            
            // PPG Data Card
            if let ppgReading = bluetoothKit.latestPPGReading {
                PPGDataCard(reading: ppgReading)
                    .frame(maxWidth: .infinity)
            }
            
            // Accelerometer Data Card
            if let accelReading = bluetoothKit.latestAccelerometerReading {
                AccelerometerDataCard(reading: accelReading)
                    .frame(maxWidth: .infinity)
            }
            
            // Battery Data Card
            if let batteryReading = bluetoothKit.latestBatteryReading {
                BatteryDataCard(reading: batteryReading)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SensorDataView(bluetoothKit: BluetoothKit())
} 