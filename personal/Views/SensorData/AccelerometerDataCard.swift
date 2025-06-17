import SwiftUI
import BluetoothKit

struct AccelerometerDataCard: View {
    let reading: AccelerometerReading
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // 헤더 섹션
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "move.3d")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("가속도계")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
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
            
            // 데이터 표시 섹션
            // BluetoothKit에서 이미 모드에 따라 처리된 데이터를 그대로 표시
            HStack(spacing: 20) {
                VStack {
                    Text("X축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.x)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Y축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.y)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Z축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.z)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    AccelerometerDataCard(
        reading: AccelerometerReading(x: 1234, y: -567, z: 890),
        bluetoothKit: BluetoothKitViewModel()
    )
} 