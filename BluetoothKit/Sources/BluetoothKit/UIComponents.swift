import SwiftUI

// MARK: - BluetoothKit UI Components

#if os(iOS)
@available(iOS 14.0, *)
public extension BluetoothKit {
    
    // MARK: - Status Card View
    
    /// Enhanced status card view that shows connection state and controls
    struct StatusCardView: View {
        @ObservedObject var bluetoothKit: BluetoothKit
        
        public init(bluetoothKit: BluetoothKit) {
            self.bluetoothKit = bluetoothKit
        }
        
        public var body: some View {
            VStack(spacing: 16) {
                // Connection Status Header
                HStack {
                    Image(systemName: connectionIcon)
                        .font(.system(size: 24))
                        .foregroundColor(connectionColor)
                        .symbolEffectIfAvailable(SymbolEffectType.bounce, value: bluetoothKit.connectionState)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bluetoothKit.connectionStatusDescription)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Recording Status
                    if bluetoothKit.isRecording {
                        VStack {
                            Image(systemName: "record.circle.fill")
                                .foregroundColor(.red)
                                .symbolEffectIfAvailable(SymbolEffectType.pulse, isActive: true)
                            Text("REC")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                if !bluetoothKit.isConnected {
                    // Scanning Controls
                    VStack(spacing: 12) {
                        if bluetoothKit.isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            
                            Button("Stop Scanning") {
                                bluetoothKit.stopScanning()
                            }
                            .compatibleButtonStyle(.bordered)
                            .compatibleTint(.red)
                        } else {
                            Button("Start Scanning") {
                                bluetoothKit.startScanning()
                            }
                            .compatibleButtonStyle(.borderedProminent)
                            .compatibleTint(.blue)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Auto-reconnect toggle
                    Divider()
                    
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        
                        Text("Auto-reconnect")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(bluetoothKit.isAutoReconnectEnabled))
                            .labelsHidden()
                            .onChange(of: bluetoothKit.isAutoReconnectEnabled) { newValue in
                                bluetoothKit.setAutoReconnect(enabled: newValue)
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    
                    // Device List
                    if !bluetoothKit.discoveredDevices.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Discovered Devices")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ForEach(bluetoothKit.discoveredDevices, id: \.id) { device in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Connect") {
                                        bluetoothKit.connect(to: device)
                                    }
                                    .compatibleButtonStyle(.bordered)
                                    .compatibleTint(.blue)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Data rate information when connected
                    Divider()
                    
                    HStack {
                        DataRateIndicator(
                            title: "EEG",
                            hasData: bluetoothKit.latestEEGReading != nil,
                            icon: "brain.head.profile"
                        )
                        
                        Spacer()
                        
                        DataRateIndicator(
                            title: "PPG",
                            hasData: bluetoothKit.latestPPGReading != nil,
                            icon: "heart.fill"
                        )
                        
                        Spacer()
                        
                        DataRateIndicator(
                            title: "ACCEL",
                            hasData: bluetoothKit.latestAccelerometerReading != nil,
                            icon: "move.3d"
                        )
                        
                        Spacer()
                        
                        DataRateIndicator(
                            title: "BATT",
                            hasData: bluetoothKit.latestBatteryReading != nil,
                            icon: "battery.75"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
        }
        
        private var connectionIcon: String {
            switch bluetoothKit.connectionState {
            case .disconnected:
                return "wave.3.right.circle"
            case .scanning:
                return "magnifyingglass.circle"
            case .connecting:
                return "arrow.triangle.2.circlepath.circle"
            case .connected:
                return "wave.3.right.circle.fill"
            case .reconnecting:
                return "arrow.clockwise.circle"
            case .failed:
                return "exclamationmark.triangle.fill"
            }
        }
        
        private var connectionColor: Color {
            switch bluetoothKit.connectionState {
            case .disconnected:
                return .gray
            case .scanning:
                return .blue
            case .connecting, .reconnecting:
                return .orange
            case .connected:
                return .green
            case .failed:
                return .red
            }
        }
    }
    
    // MARK: - Data Rate Indicator
    
    struct DataRateIndicator: View {
        let title: String
        let hasData: Bool
        let icon: String
        
        public var body: some View {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(hasData ? .green : .gray)
                    .symbolEffectIfAvailable(SymbolEffectType.pulse, isActive: hasData)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(hasData ? .green : .gray)
            }
        }
    }
    
    // MARK: - Sensor Data Cards
    
    /// EEG data display card
    struct EEGDataCard: View {
        let reading: EEGReading
        
        public init(reading: EEGReading) {
            self.reading = reading
        }
        
        public var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .font(.title2)
                    Text("EEG Data")
                        .font(.headline)
                        .foregroundColor(.purple)
                    Spacer()
                    Image(systemName: reading.leadOff ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(reading.leadOff ? .red : .green)
                }
                .frame(maxWidth: .infinity)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("CH1")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f µV", reading.channel1))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("CH2")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f µV", reading.channel2))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(reading.leadOff ? "Disconnected" : "Connected")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(reading.leadOff ? .red : .green)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    /// PPG data display card
    struct PPGDataCard: View {
        let reading: PPGReading
        
        public init(reading: PPGReading) {
            self.reading = reading
        }
        
        public var body: some View {
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
                
                HStack(spacing: 20) {
                    VStack {
                        Text("Red LED")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(reading.red)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("IR LED")
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
    
    /// Accelerometer data display card
    struct AccelerometerDataCard: View {
        let reading: AccelerometerReading
        
        public init(reading: AccelerometerReading) {
            self.reading = reading
        }
        
        public var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "move.3d")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Accelerometer")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("X")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(reading.x)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("Y")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(reading.y)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack {
                        Text("Z")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(reading.z)")
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
                    .fill(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    /// Battery data display card
    struct BatteryDataCard: View {
        let reading: BatteryReading
        
        public init(reading: BatteryReading) {
            self.reading = reading
        }
        
        public var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: batteryIcon)
                        .foregroundColor(batteryColor)
                        .font(.title2)
                    Text("Battery")
                        .font(.headline)
                        .foregroundColor(batteryColor)
                    Spacer()
                    Text("\(reading.level)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(batteryColor)
                }
                .frame(maxWidth: .infinity)
                
                // Battery level bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        
                        Rectangle()
                            .fill(batteryColor)
                            .frame(width: geometry.size.width * CGFloat(reading.level) / 100.0)
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(batteryColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(batteryColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        
        private var batteryIcon: String {
            switch reading.level {
            case 0...20:
                return "battery.25"
            case 21...50:
                return "battery.50"
            case 51...75:
                return "battery.75"
            default:
                return "battery.100"
            }
        }
        
        private var batteryColor: Color {
            switch reading.level {
            case 0...20:
                return .red
            case 21...50:
                return .orange
            default:
                return .green
            }
        }
    }
    
    // MARK: - Recording Controls
    
    /// Recording control buttons
    struct RecordingControlsView: View {
        @ObservedObject var bluetoothKit: BluetoothKit
        
        public init(bluetoothKit: BluetoothKit) {
            self.bluetoothKit = bluetoothKit
        }
        
        public var body: some View {
            VStack(spacing: 12) {
                HStack {
                    if bluetoothKit.isRecording {
                        Button(action: { bluetoothKit.stopRecording() }) {
                            Label("Stop Recording", systemImage: "stop.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .compatibleButtonStyle(.bordered)
                        .compatibleTint(.red)
                    } else {
                        Button(action: { bluetoothKit.startRecording() }) {
                            Label("Start Recording", systemImage: "record.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .compatibleButtonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
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
    
    // MARK: - Sensor Data View
    
    /// Combined sensor data display view
    struct SensorDataView: View {
        @ObservedObject var bluetoothKit: BluetoothKit
        
        public init(bluetoothKit: BluetoothKit) {
            self.bluetoothKit = bluetoothKit
        }
        
        public var body: some View {
            VStack(spacing: 16) {
                // EEG Data Card
                if let eegReading = bluetoothKit.latestEEGReading {
                    EEGDataCard(reading: eegReading)
                        .frame(maxWidth: .infinity)
                }
                
                // PPG Data Card
                if let ppgReading = bluetoothKit.latestPPGReading {
                    PPGDataCard(reading: ppgReading)
                        .frame(maxWidth: .infinity)
                }
                
                // Accelerometer Data Card
                if let accelReading = bluetoothKit.latestAccelerometerReading {
                    AccelerometerDataCard(reading: accelReading)
                        .frame(maxWidth: .infinity)
                }
                
                // Battery Data Card
                if let batteryReading = bluetoothKit.latestBatteryReading {
                    BatteryDataCard(reading: batteryReading)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - File Management Components
    
    /// File management view for recorded data
    struct RecordedFilesView: View {
        @ObservedObject var bluetoothKit: BluetoothKit
        @Environment(\.presentationMode) var presentationMode
        @State private var recordedFiles: [URL] = []
        @State private var selectedFileURL: URL?
        @State private var showingShareSheet = false
        @State private var showingQuickLook = false
        @State private var shareItems: [Any] = []
        
        public init(bluetoothKit: BluetoothKit) {
            self.bluetoothKit = bluetoothKit
        }
        
        public var body: some View {
            NavigationView {
                mainContentView
                    .navigationTitle("Recorded Files")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            toolbarContent
                        }
                    }
                    .onAppear {
                        refreshFiles()
                    }
                    .modifier(RefreshableModifier {
                        refreshFiles()
                    })
                    .sheet(isPresented: $showingShareSheet) {
                        shareSheetContent
                    }
                    .sheet(isPresented: $showingQuickLook) {
                        quickLookContent
                    }
            }
        }
        
        @ViewBuilder
        private var mainContentView: some View {
            Group {
                if recordedFiles.isEmpty {
                    emptyStateView
                } else {
                    fileListView
                }
            }
        }
        
        @ViewBuilder
        private var emptyStateView: some View {
            VStack(spacing: 16) {
                Image(systemName: "folder")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("No Recordings")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Start recording sensor data to see files here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
        @ViewBuilder
        private var fileListView: some View {
            List {
                Section(header: Text("Files")) {
                    ForEach(groupedFiles.keys.sorted().reversed(), id: \.self) { dateString in
                        Section(header: Text(dateString)) {
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
        
        @ViewBuilder
        private var toolbarContent: some View {
            if !recordedFiles.isEmpty {
                Button(action: openInFiles) {
                    Image(systemName: "folder.badge.gearshape")
                }
                .help("Open recordings directory")
            }
            
            if #available(iOS 15.0, *) {
                // Refresh is handled by .refreshable
            } else {
                Button(action: refreshFiles) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh files")
            }
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
        }
        
        @ViewBuilder
        private var shareSheetContent: some View {
            if !shareItems.isEmpty {
                ShareSheet(items: shareItems)
            }
        }
        
        @ViewBuilder
        private var quickLookContent: some View {
            if let url = selectedFileURL {
                QuickLookView(url: url)
            }
        }
        
        private struct RefreshableModifier: ViewModifier {
            let action: () -> Void
            
            func body(content: Content) -> some View {
                if #available(iOS 15.0, *) {
                    content.refreshable {
                        action()
                    }
                } else {
                    content
                }
            }
        }
        
        private var groupedFiles: [String: [URL]] {
            Dictionary(grouping: recordedFiles) { url in
                let fileName = url.lastPathComponent
                if let dateStr = fileName.components(separatedBy: "_").first,
                   dateStr.count == 8 {
                    let year = String(dateStr.prefix(4))
                    let month = String(dateStr.dropFirst(4).prefix(2))
                    let day = String(dateStr.dropFirst(6).prefix(2))
                    return "\(year)-\(month)-\(day)"
                }
                return "Other"
            }
        }
        
        private func refreshFiles() {
            recordedFiles = bluetoothKit.recordedFiles.sorted { url1, url2 in
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
            if let url = URL(string: "files://") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    /// Individual file row view
    struct FileRowView: View {
        let url: URL
        let onTap: () -> Void
        let onShare: () -> Void
        
        public init(url: URL, onTap: @escaping () -> Void, onShare: @escaping () -> Void) {
            self.url = url
            self.onTap = onTap
            self.onShare = onShare
        }
        
        public var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text(fileType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
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
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
        
        private var fileName: String {
            url.lastPathComponent
        }
        
        private var fileType: String {
            let components = fileName.components(separatedBy: "_")
            if components.count >= 3 {
                return components[2].replacingOccurrences(of: ".csv", with: "").uppercased()
            }
            return url.pathExtension.uppercased()
        }
        
        private var fileSize: String {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? Int64 else {
                return "Unknown"
            }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }
}

// MARK: - Helper Extensions
extension View {
    @ViewBuilder
    func symbolEffectIfAvailable<T: Equatable>(_ effect: SymbolEffectType, value: T) -> some View {
        if #available(iOS 18.0, *) {
            switch effect {
            case .bounce:
                self.symbolEffect(.bounce, value: value)
            case .pulse:
                self.symbolEffect(.pulse, value: value)
            }
        } else {
            self
        }
    }
    
    @ViewBuilder 
    func symbolEffectIfAvailable(_ effect: SymbolEffectType, isActive: Bool) -> some View {
        if #available(iOS 18.0, *) {
            switch effect {
            case .bounce:
                self.symbolEffect(.bounce, isActive: isActive)
            case .pulse:
                self.symbolEffect(.pulse, isActive: isActive)
            }
        } else {
            self
        }
    }
    
    @ViewBuilder
    func compatibleButtonStyle(_ style: CompatibleButtonStyle) -> some View {
        if #available(iOS 15.0, *) {
            switch style {
            case .bordered:
                self.buttonStyle(.bordered)
            case .borderedProminent:
                self.buttonStyle(.borderedProminent)
            }
        } else {
            switch style {
            case .bordered:
                self.buttonStyle(iOS14BorderedButtonStyle())
            case .borderedProminent:
                self.buttonStyle(iOS14ProminentButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    func compatibleTint(_ color: Color) -> some View {
        if #available(iOS 15.0, *) {
            self.tint(color)
        } else {
            self.accentColor(color)
        }
    }
}

// MARK: - Compatible Button Styles
enum CompatibleButtonStyle {
    case bordered
    case borderedProminent
}

// iOS 14 compatible button styles
struct iOS14BorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1)
                    .background(Color.clear)
            )
            .foregroundColor(.accentColor)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct iOS14ProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Symbol Effect Type
enum SymbolEffectType {
    case bounce
    case pulse
}

// MARK: - Helper Views for File Management

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        // Basic implementation - in a real app you'd use QuickLook framework
        let textView = UITextView()
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        if let content = try? String(contentsOf: url) {
            textView.text = content
        } else {
            textView.text = "Unable to preview file: \(url.lastPathComponent)"
        }
        
        controller.view = textView
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif 