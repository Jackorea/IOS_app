import SwiftUI
import BluetoothKit

// MARK: - Recording Controls View

/// 센서 데이터 기록을 시작/중지하는 컨트롤 뷰
struct RecordingControlsView: View {
    @ObservedObject var bluetoothViewModel: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HStack {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                
                Text("기록 컨트롤")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if bluetoothViewModel.isRecording {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                        .symbolEffect(.pulse)
                }
            }
            
            Divider()
            
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
                        .font(.title2)
                    
                    Text(bluetoothViewModel.isRecording ? "기록 중지" : "기록 시작")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(bluetoothViewModel.isRecording ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!bluetoothViewModel.isConnected)
            
            // 상태 정보
            if bluetoothViewModel.isConnected {
                VStack(spacing: 8) {
                    HStack {
                        Text("저장 위치:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Documents 폴더")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("파일 형식:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("CSV")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(.top, 8)
            } else {
                Text("디바이스에 연결 후 기록할 수 있습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
    RecordingControlsView(bluetoothViewModel: BluetoothKitViewModel())
} 