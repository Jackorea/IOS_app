import SwiftUI
import BluetoothKit

struct AccelerometerDataCard: View {
    let reading: AccelerometerReading
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "move.3d")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Accelerometer")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("X")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.x)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("Y")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.y)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("Z")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.z)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
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
    AccelerometerDataCard(reading: AccelerometerReading(x: 1234, y: -567, z: 890))
} 