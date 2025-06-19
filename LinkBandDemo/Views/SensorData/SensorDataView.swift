import SwiftUI
import BluetoothKit

// MARK: - 센서 데이터 뷰

struct SensorDataView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // EEG 데이터 카드
            if let eegReading = bluetoothKit.latestEEGReading {
                EEGDataCard(reading: eegReading)
                    .frame(maxWidth: .infinity)
            }
            
            // PPG 데이터 카드
            if let ppgReading = bluetoothKit.latestPPGReading {
                PPGDataCard(reading: ppgReading)
                    .frame(maxWidth: .infinity)
            }
            
            // 가속도계 데이터 카드
            if let accelReading = bluetoothKit.latestAccelerometerReading {
                AccelerometerDataCard(reading: accelReading, bluetoothKit: bluetoothKit)
                    .frame(maxWidth: .infinity)
            }
            
            // 배터리 데이터 카드
            if let batteryReading = bluetoothKit.latestBatteryReading {
                BatteryDataCard(reading: batteryReading)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SensorDataView(bluetoothKit: BluetoothKitViewModel())
} 