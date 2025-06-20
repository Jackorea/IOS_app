import SwiftUI

struct AccelerometerModeControlView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // 세그먼트 컨트롤 스타일의 토글
            HStack(spacing: 0) {
                // 원시값 버튼
                Button(action: {
                    bluetoothKit.accelerometerMode = .raw
                }) {
                    Text("원시값")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(bluetoothKit.accelerometerMode == .raw ? Color.blue : Color.clear)
                        )
                        .foregroundColor(bluetoothKit.accelerometerMode == .raw ? .white : .blue)
                }
                .disabled(bluetoothKit.isRecording)
                
                // 움직임 버튼
                Button(action: {
                    bluetoothKit.accelerometerMode = .motion
                }) {
                    Text("움직임")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(bluetoothKit.accelerometerMode == .motion ? Color.blue : Color.clear)
                        )
                        .foregroundColor(bluetoothKit.accelerometerMode == .motion ? .white : .blue)
                }
                .disabled(bluetoothKit.isRecording)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .opacity(bluetoothKit.isRecording ? 0.5 : 1.0)
            
            // 설명 텍스트
            HStack {
                Text(bluetoothKit.accelerometerMode.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
    }
}

#Preview {
    AccelerometerModeControlView(bluetoothKit: BluetoothKitViewModel())
} 