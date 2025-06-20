import SwiftUI

// MARK: - Controls View

struct ControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 자동 재연결 토글
            HStack {
                Label("자동 재연결", systemImage: "arrow.clockwise.circle")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Toggle("", isOn: $bluetoothKit.isAutoReconnectEnabled)
                    .labelsHidden()
                    .onChange(of: bluetoothKit.isAutoReconnectEnabled) { newValue in
                        bluetoothKit.setAutoReconnect(enabled: newValue)
                    }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // 연결 제어 버튼
            if bluetoothKit.isConnected {
                Button(action: { bluetoothKit.disconnect() }) {
                    Label("연결 해제", systemImage: "wifi.slash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ControlsView(bluetoothKit: BluetoothKitViewModel())
} 