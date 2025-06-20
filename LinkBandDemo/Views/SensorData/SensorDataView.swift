import SwiftUI
// 모든 타입들이 같은 모듈 내에 있으므로 별도 import 불필요

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
            
            // 가속도계 데이터 카드 (모드 제어 포함)
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