import SwiftUI
import BluetoothKit

struct EEGDataCard: View {
    let reading: EEGReading
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("EEG Data")
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
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(reading.leadOff ? "Disconnected" : "Connected")
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
    EEGDataCard(reading: EEGReading(channel1: 125.5, channel2: -88.2, leadOff: false))
} 