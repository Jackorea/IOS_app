import SwiftUI
import BluetoothKit
import UniformTypeIdentifiers

// MARK: - Recorded Files View

struct RecordedFilesView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    @Environment(\.dismiss) private var dismiss
    @State private var recordedFiles: [URL] = []
    @State private var selectedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingQuickLook = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationStack {
            Group {
                if recordedFiles.isEmpty {
                    ContentUnavailableView(
                        "기록 파일 없음",
                        systemImage: "folder",
                        description: Text("센서 데이터 기록을 시작하면 여기에 파일이 표시됩니다.")
                    )
                } else {
                    List {
                        // Files list
                        Section("파일") {
                            ForEach(groupedFiles.keys.sorted().reversed(), id: \.self) { dateString in
                                Section(dateString) {
                                    ForEach(groupedFiles[dateString] ?? [], id: \.self) { url in
                                        FileRowView(
                                            url: url,
                                            onTap: { previewFile(url) },
                                            onShare: { shareFile(url) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("기록된 파일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !recordedFiles.isEmpty {
                        Button(action: openInFiles) {
                            Image(systemName: "folder.badge.gearshape")
                        }
                        .help("Open recordings directory info")
                    }
                    
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshFiles()
            }
            .refreshable {
                refreshFiles()
            }
            .sheet(isPresented: $showingShareSheet) {
                if !shareItems.isEmpty {
                    ShareSheet(items: shareItems)
                }
            }
            .sheet(isPresented: $showingQuickLook) {
                if let url = selectedFileURL {
                    QuickLookView(url: url)
                }
            }
        }
    }
    
    private var groupedFiles: [String: [URL]] {
        Dictionary(grouping: recordedFiles) { url in
            let fileName = url.lastPathComponent
            // Extract date from filename (assuming format: YYYYMMDD_HHMMSS_type.ext)
            if let dateStr = fileName.components(separatedBy: "_").first,
               dateStr.count == 8 {
                let year = String(dateStr.prefix(4))
                let month = String(dateStr.dropFirst(4).prefix(2))
                let day = String(dateStr.dropFirst(6).prefix(2))
                return "\(year)-\(month)-\(day)"
            }
            return "기타"
        }
    }
    
    private var totalFileSize: String {
        let totalBytes = recordedFiles.compactMap { url in
            try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
        }.reduce(0, +)
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    private func refreshFiles() {
        recordedFiles = bluetoothKit.recordedFiles.sorted { url1, url2 in
            // Sort by modification date, newest first
            let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.modificationDate] as? Date) ?? Date.distantPast
            let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.modificationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func previewFile(_ url: URL) {
        selectedFileURL = url
        showingQuickLook = true
    }
    
    private func shareFile(_ url: URL) {
        shareItems = [url]
        showingShareSheet = true
    }
    
    private func openInFiles() {
        // Try multiple approaches to open the recordings directory
        
        // Method 1: Try to open Files app with shareddocuments URL scheme
        if let appName = Bundle.main.appDisplayName {
            let filesURL = "shareddocuments://\(appName)"
            if let url = URL(string: filesURL), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if !success {
                        // Fallback to method 2
                        self.openFilesAppFallback()
                    }
                }
                return
            }
        }
        
        // Method 2: Try to open Files app directly
        let filesAppURL = "files://"
        if let url = URL(string: filesAppURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to method 3
                    self.showFilesInstructions()
                }
            }
        } else {
            // Method 3: Show instructions as fallback
            showFilesInstructions()
        }
    }
    
    private func openFilesAppFallback() {
        // Try alternative URL schemes for Files app
        let alternativeURLs = [
            "com.apple.DocumentsApp://",
            "files://",
        ]
        
        for urlString in alternativeURLs {
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // If all fails, show options dialog
        showFileAccessOptions()
    }
    
    private func showFileAccessOptions() {
        let alert = UIAlertController(
            title: "Access Your Recordings",
            message: "Choose how you'd like to access your recorded files:",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "📁 Open Files App", style: .default) { _ in
            if let url = URL(string: "files://") {
                UIApplication.shared.open(url)
            } else {
                self.showFilesInstructions()
            }
        })
        
        alert.addAction(UIAlertAction(title: "📋 Browse Files Here", style: .default) { _ in
            self.showDocumentPicker()
        })
        
        alert.addAction(UIAlertAction(title: "❓ Show Instructions", style: .default) { _ in
            self.showFilesInstructions()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad, we need to set the source view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            if let popover = alert.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func showDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder, .data])
        documentPicker.allowsMultipleSelection = false
        documentPicker.shouldShowFileExtensions = true
        
        // Try to start from the recordings directory
        documentPicker.directoryURL = bluetoothKit.recordingsDirectory
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(documentPicker, animated: true)
        }
    }
    
    private func showFilesInstructions() {
        let appName = Bundle.main.appDisplayName ?? "Personal"
        
        let alert = UIAlertController(
            title: "Access Your Recordings",
            message: """
            📁 To access your recordings:
            
            🔍 Method 1 - Files App:
            1. Open the "Files" app
            2. Tap "On My iPhone/iPad"
            3. Find "\(appName)"
            4. Open "Documents" folder
            
            📤 Method 2 - Share:
            Use the share buttons in this app to send files directly to other apps or cloud storage.
            
            💡 Tip: Your recordings are safely stored in the app's Documents folder and can be accessed anytime through this app.
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Files App", style: .default) { _ in
            if let settingsUrl = URL(string: "files://") {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Bundle Extension (Local)

private extension Bundle {
    var appDisplayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

#Preview {
    RecordedFilesView(bluetoothKit: BluetoothKit())
} 