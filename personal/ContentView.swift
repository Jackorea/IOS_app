//
//  ContentView.swift
//  personal
//
//  Enhanced example app demonstrating BluetoothKit capabilities
//

import Foundation
import SwiftUI
import CoreBluetooth
import BluetoothKit
import UniformTypeIdentifiers

// REMOVE BluetoothDevice struct if it exists here
// REMOVE SensorUUID struct if it exists here

// BluetoothViewModel class and its extensions will be moved

struct ContentView: View {
    @StateObject private var bluetoothKit: BluetoothKit
    @State private var showingSettings = false
    @State private var showingRecordedFiles = false

    init() {
        self._bluetoothKit = StateObject(wrappedValue: BluetoothKit())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Enhanced Status Card
                    EnhancedStatusCardView(bluetoothKit: bluetoothKit)
                    
                    // Real-time Data Display (only when connected)
                    if bluetoothKit.isConnected {
                        SensorDataView(bluetoothKit: bluetoothKit)
                        RecordingControlsView(bluetoothKit: bluetoothKit)
                    } else {
                        ScanningControlsView(bluetoothKit: bluetoothKit)
                        DeviceListView(bluetoothKit: bluetoothKit)
                    }
                    
                    // Enhanced Controls
                    ControlsView(bluetoothKit: bluetoothKit)
                }
                .padding()
            }
            .navigationTitle(bluetoothKit.isConnected ? "Sensor Monitor" : "Device Scanner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingRecordedFiles = true }) {
                        Image(systemName: "folder.fill")
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .alert("Bluetooth is turned off", isPresented: $bluetoothKit.showBluetoothOffAlert) {
                Button("Settings", action: openBluetoothSettings)
                Button("Close", role: .cancel) { }
            } message: {
                Text("Please turn on Bluetooth to scan and connect to sensor devices.")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(bluetoothKit: bluetoothKit)
            }
            .sheet(isPresented: $showingRecordedFiles) {
                RecordedFilesView(bluetoothKit: bluetoothKit)
            }
        }
    }
    
    private func openBluetoothSettings() {
        if let settingsUrl = URL(string: "App-Prefs:Bluetooth") {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Enhanced Status Card View

struct EnhancedStatusCardView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Connection Status Icon
                Image(systemName: connectionIcon)
                    .font(.system(size: 24))
                    .foregroundColor(connectionColor)
                    .symbolEffect(.bounce, value: bluetoothKit.connectionState)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bluetoothKit.connectionStatusDescription)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if bluetoothKit.isConnected {
                        Text("Ready for data collection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Recording Status
                if bluetoothKit.isRecording {
                    VStack {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                            .symbolEffect(.pulse)
                        Text("REC")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Progress indicator for scanning
            if bluetoothKit.isScanning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.2)
            }
            
            // Data rate information when connected
            if bluetoothKit.isConnected {
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

struct DataRateIndicator: View {
    let title: String
    let hasData: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(hasData ? .green : .gray)
                .symbolEffect(.pulse, isActive: hasData)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(hasData ? .green : .gray)
        }
    }
}

// MARK: - Controls View

struct ControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 12) {
            // Auto-reconnect toggle
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                
                Text("Auto-reconnect")
                    .font(.subheadline)
                
                Spacer()
                
                Toggle("", isOn: .constant(true)) // This would need a binding to auto-reconnect setting
                    .labelsHidden()
            }
            .padding(.horizontal)
            
            Divider()
            
            // Connection controls
            HStack(spacing: 16) {
                if bluetoothKit.isConnected {
                    Button(action: { bluetoothKit.disconnect() }) {
                        Label("Disconnect", systemImage: "link.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button(action: { bluetoothKit.startScanning() }) {
                        Label("Scan", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bluetoothKit.isScanning)
                    
                    if bluetoothKit.isScanning {
                        Button(action: { bluetoothKit.stopScanning() }) {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
            .padding(.horizontal)
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

// MARK: - Sensor Data View

struct SensorDataView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(spacing: 16) {
            // EEG Data Card
            if let eegReading = bluetoothKit.latestEEGReading {
                EEGDataCard(reading: eegReading)
            }
            
            // PPG Data Card
            if let ppgReading = bluetoothKit.latestPPGReading {
                PPGDataCard(reading: ppgReading)
            }
            
            // Accelerometer Data Card
            if let accelReading = bluetoothKit.latestAccelerometerReading {
                AccelerometerDataCard(reading: accelReading)
            }
            
            // Battery Data Card
            if let batteryReading = bluetoothKit.latestBatteryReading {
                BatteryDataCard(reading: batteryReading)
            }
        }
    }
}

// MARK: - Individual Sensor Cards

struct EEGDataCard: View {
    let reading: EEGReading
    
    var body: some View {
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
            
            HStack(spacing: 20) {
                VStack {
                    Text("CH1")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f µV", reading.channel1))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("CH2")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f µV", reading.channel2))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(reading.leadOff ? "Disconnected" : "Connected")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(reading.leadOff ? .red : .green)
                }
            }
        }
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

struct PPGDataCard: View {
    let reading: PPGReading
    
    var body: some View {
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
            
            HStack(spacing: 30) {
                VStack {
                    Text("Red")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.red)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("IR")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.ir)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
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

struct AccelerometerDataCard: View {
    let reading: AccelerometerReading
    
    var body: some View {
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
            
            HStack(spacing: 20) {
                VStack {
                    Text("X")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.x)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("Y")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.y)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("Z")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(reading.z)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
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

struct BatteryDataCard: View {
    let reading: BatteryReading
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "battery.100")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Battery")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            
            VStack {
                Text("Level")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(reading.level)%")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

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

// MARK: - Scanning Controls

struct ScanningControlsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        Text("Scanning controls placeholder")
            .foregroundColor(.secondary)
    }
}

// MARK: - Device List

struct DeviceListView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discovered Devices")
                .font(.headline)
            
            if bluetoothKit.discoveredDevices.isEmpty {
                Text("No devices found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(bluetoothKit.discoveredDevices, id: \.id) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Button("Connect") {
                            bluetoothKit.connect(to: device)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var bluetoothKit: BluetoothKit
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bluetooth Settings") {
                    HStack {
                        Text("Auto-reconnect")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("Connection Status")
                        Spacer()
                        Text(bluetoothKit.connectionStatusDescription)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("BluetoothKit Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Supported Devices")
                        Spacer()
                        Text("LXB-series")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

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
                        "No Recordings",
                        systemImage: "folder",
                        description: Text("Start recording sensor data to see files here.")
                    )
                } else {
                    List {
                        // Summary section
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    Text("Recordings Folder")
                                        .font(.headline)
                                    Spacer()
                                    Button("Share All") {
                                        shareAllFiles()
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                                
                                Text("\(recordedFiles.count) files • \(totalFileSize)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Location: Documents/")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Files list
                        Section("Files") {
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
            .navigationTitle("Recorded Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !recordedFiles.isEmpty {
                        Button(action: openInFiles) {
                            Image(systemName: "folder.badge.gearshape")
                        }
                        .help("Open recordings directory info")
                    }
                    
                    Button("Done") {
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
            return "Other"
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
    
    private func shareAllFiles() {
        shareItems = recordedFiles
        showingShareSheet = true
    }
    
    private func openInFiles() {
        // Try multiple approaches to open the recordings directory
        
        // Method 1: Try to open Files app with shareddocuments URL scheme
        if let appName = Bundle.main.displayName ?? Bundle.main.bundleName {
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
        let appName = Bundle.main.displayName ?? Bundle.main.bundleName ?? "Personal"
        
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
                            Text(DateFormatter.fileDate.string(from: modDate))
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

import QuickLook

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

// MARK: - Extensions

private extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String
    }
    
    var bundleName: String? {
        return object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

private extension DateFormatter {
    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ContentView()
}
