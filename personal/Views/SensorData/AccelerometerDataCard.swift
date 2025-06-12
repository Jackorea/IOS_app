import SwiftUI
import BluetoothKit

struct AccelerometerDataCard: View {
    let reading: AccelerometerReading
    
    // 토글 상태 및 중력 추정값 저장
    @State private var showRawData = true
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
                    
                    // 개선된 토글 버튼
                    Button(action: {
                        showRawData.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showRawData ? "chart.bar" : "move.3d")
                                .font(.caption)
                            Text(showRawData ? "원시 데이터" : "움직임 감지")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 설명 텍스트
                HStack {
                    Text(showRawData ? 
                         "센서 원시값 (중력 포함)" : 
                         "순수 움직임 (중력 제거)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    if showRawData {
                        Text("단위: LSB")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("단위: LSB")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 움직임 감지 모드일 때 중력 상태 표시
            if !showRawData {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("중력 성분 자동 제거됨")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    if isInitialized {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("안정화 완료")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("중력 보정 중...")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // 데이터 표시 섹션
            HStack(spacing: 20) {
                VStack {
                    Text("X축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(showRawData ? reading.x : linearAccelX)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(showRawData ? .primary : (abs(linearAccelX) > 100 ? .red : .green))
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Y축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(showRawData ? reading.y : linearAccelY)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(showRawData ? .primary : (abs(linearAccelY) > 100 ? .red : .green))
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Z축")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(showRawData ? reading.z : linearAccelZ)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(showRawData ? .primary : (abs(linearAccelZ) > 100 ? .red : .green))
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
    AccelerometerDataCard(reading: AccelerometerReading(x: 1234, y: -567, z: 890))
} 