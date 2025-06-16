import SwiftUI
import BluetoothKit

struct AccelerometerDataCard: View {
    let reading: AccelerometerReading
    
    // Computed property to calculate magnitude - this avoids complex inline expressions
    private var magnitude: Double {
        let xSquared = Double(reading.x * reading.x)
        let ySquared = Double(reading.y * reading.y) 
        let zSquared = Double(reading.z * reading.z)
        return sqrt(xSquared + ySquared + zSquared)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: "move.3d")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                Text("가속도계")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(timeString(from: reading.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // X, Y, Z 축 데이터
            HStack(spacing: 16) {
                axisDataView(label: "X", value: reading.x, color: .red)
                axisDataView(label: "Y", value: reading.y, color: .green)
                axisDataView(label: "Z", value: reading.z, color: .blue)
            }
            
            // 총 가속도 벡터 크기
            HStack {
                Text("총 가속도")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.2f g", magnitude))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private func axisDataView(label: String, value: Int16, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
            
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("counts")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    AccelerometerDataCard(reading: AccelerometerReading(
        x: 120,
        y: -45,
        z: 890,
        timestamp: Date()
    ))
} 