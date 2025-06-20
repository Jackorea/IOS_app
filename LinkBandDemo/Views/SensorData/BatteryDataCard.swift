import SwiftUI

// MARK: - Battery Data Card

struct BatteryDataCard: View {
    let reading: BatteryData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "battery.75")
                    .foregroundColor(batteryColor)
                Text("배터리 레벨")
                    .font(.headline)
                Spacer()
                Text("\(reading.level)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(batteryColor)
            }
            .frame(maxWidth: .infinity)
            
            ProgressView(value: Double(reading.level), total: 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: batteryColor))
                .frame(maxWidth: .infinity)
            
            Text("마지막 업데이트: \(timeFormatter.string(from: reading.timestamp))")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(batteryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
    
    private var batteryColor: Color {
        if reading.level > 50 {
            return .green
        } else if reading.level > 20 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    BatteryDataCard(reading: BatteryData(level: 75, timestamp: Date()))
} 