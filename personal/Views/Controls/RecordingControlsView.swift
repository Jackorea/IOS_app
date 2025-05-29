import SwiftUI
import BluetoothKit

// MARK: - Recording Controls

struct RecordingControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if bluetoothKit.isRecording {
                    Button(action: { bluetoothKit.stopRecording() }) {
                        Label("Stop Recording", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button(action: { bluetoothKit.startRecording() }) {
                        Label("Start Recording", systemImage: "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if !bluetoothKit.recordedFiles.isEmpty {
                Text("\(bluetoothKit.recordedFiles.count) recorded files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    RecordingControlsView(bluetoothKit: BluetoothKit())
} 