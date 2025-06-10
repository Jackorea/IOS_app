import SwiftUI
import BluetoothKit

// MARK: - 기록 컨트롤

/// 센서 데이터 기록을 시작/중지하는 컨트롤 뷰
struct RecordingControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        Button(action: {
            if bluetoothKit.isRecording {
                bluetoothKit.stopRecording()
            } else {
                bluetoothKit.startRecording()
            }
        }) {
            if bluetoothKit.isRecording {
                Label("기록 중지", systemImage: "stop.circle.fill")
                    .foregroundColor(.red)
                    .font(.headline)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Label("기록 시작", systemImage: "record.circle")
                    .foregroundColor(.blue)
                    .font(.headline)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .disabled(!bluetoothKit.isConnected)
    }
}

#Preview {
    RecordingControlsView(bluetoothKit: BluetoothKit())
} 