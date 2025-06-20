import SwiftUI

// EEGData 타입은 BluetoothKitViewModel에 정의되어 있습니다
// 현재 프로젝트 구조에서는 같은 모듈이므로 import가 필요하지 않아야 하는데
// View와 ViewModel이 다른 타겟에 있을 수 있으므로 확인이 필요합니다

struct EEGDataCard: View {
    let reading: EEGData
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("EEG 데이터")
                    .font(.headline)
                    .foregroundColor(.purple)
                Spacer()
                Image(systemName: reading.leadOff ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(reading.leadOff ? .red : .green)
            }
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 20) {
                VStack {
                    Text("CH1")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f µV", reading.channel1))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("CH2")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f µV", reading.channel2))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("센서 접촉 상태")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(reading.leadOff ? "접촉 안됨" : "접촉됨")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(reading.leadOff ? .red : .green)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    EEGDataCard(reading: EEGData(channel1: 125.5, channel2: -88.2, ch1Raw: 5000, ch2Raw: -3500, leadOff: false, timestamp: Date()))
} 