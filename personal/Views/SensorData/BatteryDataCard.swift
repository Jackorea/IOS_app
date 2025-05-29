import SwiftUI
import BluetoothKit

struct BatteryDataCard: View {
    let reading: BatteryReading
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "battery.100")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Battery")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            
            VStack {
                Text("Level")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(reading.level)%")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    BatteryDataCard(reading: BatteryReading(level: 75))
} 