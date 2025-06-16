import SwiftUI
import BluetoothKit
import QuickLook

// MARK: - Recorded Files View

struct RecordedFilesView: View {
    @ObservedObject var bluetoothViewModel: BluetoothKitViewModel
    @State private var selectedFileURL: URL?
    @State private var showingQuickLook = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if bluetoothViewModel.recordedFiles.isEmpty {
                    emptyStateView
                } else {
                    filesList
                }
            }
            .navigationTitle("기록된 파일")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if !bluetoothViewModel.recordedFiles.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("모든 파일 공유") {
                                shareAllFiles()
                            }
                            
                            Button("모든 파일 삭제", role: .destructive) {
                                showingDeleteAllAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingQuickLook) {
                if let url = selectedFileURL {
                    QuickLookView(url: url)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
            .alert("파일 삭제", isPresented: $showingDeleteAlert) {
                Button("삭제", role: .destructive) {
                    if let url = selectedFileURL {
                        deleteFile(url)
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("선택한 파일을 삭제하시겠습니까?")
            }
            .alert("모든 파일 삭제", isPresented: $showingDeleteAllAlert) {
                Button("모든 파일 삭제", role: .destructive) {
                    deleteAllFiles()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("기록된 모든 파일을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
            }
        }
        .onAppear {
            bluetoothViewModel.refreshRecordedFiles()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("기록된 파일이 없습니다")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("센서 데이터를 기록하면 여기에 파일이 표시됩니다.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("기록 시작하기") {
                presentationMode.wrappedValue.dismiss()
                // 메인 화면으로 돌아가서 기록 시작
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var filesList: some View {
        List {
            ForEach(bluetoothViewModel.recordedFiles, id: \.absoluteString) { fileURL in
                FileRowView(
                    url: fileURL,
                    onTap: {
                        selectedFileURL = fileURL
                        showingQuickLook = true
                    },
                    onShare: {
                        shareFile(fileURL)
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("삭제", role: .destructive) {
                        selectedFileURL = fileURL
                        showingDeleteAlert = true
                    }
                    
                    Button("공유") {
                        shareFile(fileURL)
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            bluetoothViewModel.refreshRecordedFiles()
        }
    }
    
    private func shareFile(_ url: URL) {
        shareItems = [url]
        showingShareSheet = true
    }
    
    private func shareAllFiles() {
        shareItems = bluetoothViewModel.recordedFiles
        showingShareSheet = true
    }
    
    private func deleteFile(_ url: URL) {
        do {
            try bluetoothViewModel.deleteFile(url)
            
            // 성공 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        } catch {
            print("파일 삭제 실패: \(error)")
            
            // 실패 시 사용자에게 알림
            showFilesInstructions()
        }
    }
    
    private func deleteAllFiles() {
        do {
            try bluetoothViewModel.deleteAllFiles()
            
            // 성공 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        } catch {
            print("모든 파일 삭제 실패: \(error)")
            
            // 실패 시 사용자에게 알림
            showFilesInstructions()
        }
    }
    
    // 파일 액세스 관련 안내를 표시하는 메서드
    private func showFilesInstructions() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
            return
        }
        
        let alert = UIAlertController(
            title: "파일 위치",
            message: "기록된 파일은 다음 위치에 저장됩니다:\n\n\(documentsPath)\n\n파일 앱에서 직접 접근할 수도 있습니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "파일 앱 열기", style: .default) { _ in
            if let filesURL = URL(string: "shareddocuments://") {
                UIApplication.shared.open(filesURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "❓ Show Instructions", style: .default) { _ in
            self.showFilesInstructions()
        })
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
}

#Preview {
    RecordedFilesView(bluetoothViewModel: BluetoothKitViewModel())
} 