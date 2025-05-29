import SwiftUI
import BluetoothKit

// MARK: - Controls View

struct ControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    @State private var autoReconnectEnabled: Bool = true
    
    var body: some View {
        VStack(spacing: 12) {
            // Auto-reconnect toggle
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                
                Text("Auto-reconnect")
                    .font(.subheadline)
                
                Spacer()
                
                Toggle("", isOn: $autoReconnectEnabled)
                    .labelsHidden()
                    .onChange(of: autoReconnectEnabled) { newValue in
                        bluetoothKit.setAutoReconnect(enabled: newValue)
                    }
            }
            .padding(.horizontal)
            
            // Connection controls - only show disconnect when connected
            if bluetoothKit.isConnected {
                Divider()
                
                Button(action: { bluetoothKit.disconnect() }) {
                    Label("Disconnect", systemImage: "link.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ControlsView(bluetoothKit: BluetoothKit())
} 