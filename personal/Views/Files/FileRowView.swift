import SwiftUI
import UIKit
import QuickLook

struct FileRowView: View {
    let url: URL
    let onTap: () -> Void
    let onShare: () -> Void
    @State private var fileAttributes: [FileAttributeKey: Any]?
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(fileType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(fileTypeColor.opacity(0.2))
                            .foregroundColor(fileTypeColor)
                            .cornerRadius(4)
                        
                        if let modDate = modificationDate {
                            Text(FileHelper.dateFormatter.string(from: modDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(fileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            loadFileAttributes()
        }
    }
    
    private var fileType: String {
        switch url.pathExtension.lowercased() {
        case "csv":
            if url.lastPathComponent.contains("eeg") {
                return "EEG"
            } else if url.lastPathComponent.contains("ppg") {
                return "PPG"
            } else if url.lastPathComponent.contains("accel") {
                return "ACCEL"
            } else {
                return "CSV"
            }
        case "json":
            return "RAW"
        default:
            return "FILE"
        }
    }
    
    private var fileTypeColor: Color {
        switch fileType {
        case "EEG": return .purple
        case "PPG": return .red
        case "ACCEL": return .blue
        case "RAW": return .orange
        default: return .gray
        }
    }
    
    private var fileSize: String {
        guard let size = fileAttributes?[.size] as? Int64 else {
            return "Unknown"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private var modificationDate: Date? {
        return fileAttributes?[.modificationDate] as? Date
    }
    
    private func loadFileAttributes() {
        fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    }
}

// MARK: - Helper Views

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToVimeo,
            .postToTencentWeibo,
            .postToFlickr
        ]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QuickLookViewController(url: url)
        return UINavigationController(rootViewController: controller)
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

class QuickLookViewController: UIViewController, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    private let url: URL
    private var previewController: QLPreviewController!
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        
        addChild(previewController)
        view.addSubview(previewController.view)
        previewController.view.frame = view.bounds
        previewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewController.didMove(toParent: self)
        
        navigationItem.title = url.lastPathComponent
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissView)
        )
    }
    
    @objc private func dismissView() {
        dismiss(animated: true)
    }
    
    // MARK: - QLPreviewControllerDataSource
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return url as QLPreviewItem
    }
}

// MARK: - File Helper

struct FileHelper {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    let sampleURL = URL(fileURLWithPath: "/tmp/sample_eeg_data.csv")
    FileRowView(url: sampleURL, onTap: {}, onShare: {})
} 