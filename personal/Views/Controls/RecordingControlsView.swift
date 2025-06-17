import SwiftUI
import BluetoothKit

// MARK: - 기록 컨트롤

/// 센서 데이터 기록을 시작/중지하는 컨트롤 뷰
struct RecordingControlsView: View {
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
            .frame(maxWidth: .infinity)
            
            Button(action: {
                if bluetoothKit.isRecording {
                    bluetoothKit.stopRecording()
                } else {
                    bluetoothKit.startRecording()
                }
            }) {
                HStack {
                    Spacer()
                    Text(bluetoothKit.isRecording ? "중지" : "시작")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bluetoothKit.isRecording ? Color.red : Color.blue)
                )
            }
            .disabled(!bluetoothKit.isConnected)
            .opacity(bluetoothKit.isConnected ? 1.0 : 0.5)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((bluetoothKit.isRecording ? Color.red : Color.blue).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((bluetoothKit.isRecording ? Color.red : Color.blue).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    RecordingControlsView(bluetoothKit: BluetoothKitViewModel())
} 