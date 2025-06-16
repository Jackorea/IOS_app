import SwiftUI
import BluetoothKit

// MARK: - Controls View

struct ControlsView: View {
    @ObservedObject var bluetoothViewModel: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("디바이스 컨트롤")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Divider()
            
            VStack(spacing: 12) {
                // 연결 버튼
                Button(action: {
                    if bluetoothViewModel.isConnected {
                        bluetoothViewModel.disconnect()
                    } else {
                        bluetoothViewModel.startScanning()
                    }
                }) {
                    HStack {
                        Image(systemName: bluetoothViewModel.isConnected ? "xmark.circle.fill" : "magnifyingglass.circle.fill")
                        Text(bluetoothViewModel.isConnected ? "연결 해제" : "스캔 시작")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bluetoothViewModel.isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // 기록 버튼
                Button(action: {
                    if bluetoothViewModel.isRecording {
                        bluetoothViewModel.stopRecording()
                    } else {
                        bluetoothViewModel.startRecording()
                    }
                }) {
                    HStack {
                        Image(systemName: bluetoothViewModel.isRecording ? "stop.circle.fill" : "record.circle.fill")
                        Text(bluetoothViewModel.isRecording ? "기록 중지" : "기록 시작")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bluetoothViewModel.isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!bluetoothViewModel.isConnected)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

#Preview {
    ControlsView(bluetoothViewModel: BluetoothKitViewModel())
} 