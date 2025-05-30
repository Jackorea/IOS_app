import SwiftUI
import BluetoothKit

struct PPGDataCard: View {
    let reading: PPGReading
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                Text("PPG Data")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 30) {
                VStack {
                    Text("Red")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.red)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("IR")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.ir)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    PPGDataCard(reading: PPGReading(red: 65432, ir: 78901))
} 