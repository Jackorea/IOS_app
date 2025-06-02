import SwiftUI
import BluetoothKit

// MARK: - Controls View

struct ControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 12) {
            // Auto-reconnect 토글
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                
                Text("자동 재연결")
                    .font(.subheadline)
                
                Spacer()
                
                Toggle("", isOn: $bluetoothKit.isAutoReconnectEnabled)
                    .labelsHidden()
                    .onChange(of: bluetoothKit.isAutoReconnectEnabled) { newValue in
                        bluetoothKit.setAutoReconnect(enabled: newValue)
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            
            // 연결 컨트롤 - 연결된 경우에만 연결 해제 표시
            if bluetoothKit.isConnected {
                Divider()
                
                Button(action: { bluetoothKit.disconnect() }) {
                    Label("연결 해제", systemImage: "link.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
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