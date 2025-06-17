import SwiftUI
import BluetoothKit

struct AccelerometerDataCard: View {
    let reading: AccelerometerReading
    @ObservedObject var bluetoothKit: BluetoothKitViewModel
    
    // 중력 추정값 저장
    @State private var gravityX: Double = 0
    @State private var gravityY: Double = 0
    @State private var gravityZ: Double = 0
    @State private var isInitialized = false
    
    // 중력 필터링 상수 (0.1 = 느린 적응, 0.9 = 빠른 적응)
    private let gravityFilterFactor: Double = 0.1
    
    // 선형 가속도 계산 (중력 제거)
    private var linearAccelX: Int16 {
        return Int16(Double(reading.x) - gravityX)
    }
    
    private var linearAccelY: Int16 {
        return Int16(Double(reading.y) - gravityY)
    }
    
    private var linearAccelZ: Int16 {
        return Int16(Double(reading.z) - gravityZ)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 헤더 섹션
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "move.3d")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("가속도계")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                // 세그먼트 컨트롤 스타일의 토글
                HStack(spacing: 0) {
                    // 원시값 버튼
                    Button(action: {
                        bluetoothKit.accelerometerMode = .raw
                    }) {
                        Text("원시값")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bluetoothKit.accelerometerMode == .raw ? Color.blue : Color.clear)
                            )
                            .foregroundColor(bluetoothKit.accelerometerMode == .raw ? .white : .blue)
                    }
                    .disabled(bluetoothKit.isRecording)
                    
                    // 움직임 버튼
                    Button(action: {
                        bluetoothKit.accelerometerMode = .motion
                    }) {
                        Text("움직임")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bluetoothKit.accelerometerMode == .motion ? Color.blue : Color.clear)
                            )
                            .foregroundColor(bluetoothKit.accelerometerMode == .motion ? .white : .blue)
                    }
                    .disabled(bluetoothKit.isRecording)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .opacity(bluetoothKit.isRecording ? 0.5 : 1.0)
                
                // 설명 텍스트
                HStack {
                    Text(bluetoothKit.accelerometerMode.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            
            // 데이터 표시 섹션
            HStack(spacing: 20) {
                VStack {
                    Text("X축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(bluetoothKit.accelerometerMode == .raw ? reading.x : linearAccelX)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Y축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(bluetoothKit.accelerometerMode == .raw ? reading.y : linearAccelY)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Z축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(bluetoothKit.accelerometerMode == .raw ? reading.z : linearAccelZ)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            updateGravityEstimate()
        }
        .onChange(of: reading.x) { _ in
            updateGravityEstimate()
        }
        .onChange(of: reading.y) { _ in
            updateGravityEstimate()
        }
        .onChange(of: reading.z) { _ in
            updateGravityEstimate()
        }
    }
    
    // 중력 성분을 추정하고 업데이트하는 함수
    private func updateGravityEstimate() {
        if !isInitialized {
            // 첫 번째 읽기: 초기값으로 설정
            gravityX = Double(reading.x)
            gravityY = Double(reading.y)
            gravityZ = Double(reading.z)
            
            // 몇 번의 읽기 후 안정화 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isInitialized = true
            }
        } else {
            // 저역 통과 필터를 사용한 중력 추정
            gravityX = gravityX * (1 - gravityFilterFactor) + Double(reading.x) * gravityFilterFactor
            gravityY = gravityY * (1 - gravityFilterFactor) + Double(reading.y) * gravityFilterFactor
            gravityZ = gravityZ * (1 - gravityFilterFactor) + Double(reading.z) * gravityFilterFactor
        }
    }
}

#Preview {
    AccelerometerDataCard(
        reading: AccelerometerReading(x: 1234, y: -567, z: 890),
        bluetoothKit: BluetoothKitViewModel()
    )
} 