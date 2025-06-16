import SwiftUI
import BluetoothKit

// MARK: - 센서 데이터 뷰

struct SensorDataView: View {
    @ObservedObject var bluetoothViewModel: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // EEG 데이터 카드
            if let eegReading = bluetoothViewModel.latestEEGReading {
                EEGDataCard(reading: eegReading)
                    .frame(maxWidth: .infinity)
            }
            
            // PPG 데이터 카드
            if let ppgReading = bluetoothViewModel.latestPPGReading {
                PPGDataCard(reading: ppgReading)
                    .frame(maxWidth: .infinity)
            }
            
            // 가속도계 데이터 카드
            if let accelReading = bluetoothViewModel.latestAccelerometerReading {
                AccelerometerDataCard(reading: accelReading)
                    .frame(maxWidth: .infinity)
            }
            
            // 배터리 데이터 카드
            if let batteryReading = bluetoothViewModel.latestBatteryReading {
                BatteryDataCard(reading: batteryReading)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SensorDataView(bluetoothViewModel: BluetoothKitViewModel())
} 