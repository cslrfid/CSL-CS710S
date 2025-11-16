import SwiftUI
import Combine
import CSL_CS710S_Library
import AVFoundation
import AudioToolbox

@MainActor
class RfidViewModel: ObservableObject {
    // MARK: - Connection State
    @Published var isScanning = false
    @Published var discoveredReaders: [RfidReader] = []
    @Published var connectedReader: RfidReader?
    @Published var isConnecting = false
    @Published var connectionStatus = "Not Connected"
    @Published var errorMessage: String?
    @Published var showConnectionOverlay = false

    // MARK: - Inventory State
    @Published var tags: [RfidTag] = []
    @Published var isInventoryRunning = false
    @Published var uniqueTagCount = 0
    @Published var totalReadCount = 0
    @Published var readRate = 0
    @Published var elapsedTime: TimeInterval = 0

    // MARK: - Barcode State
    @Published var barcodes: [BarcodeData] = []
    @Published var isBarcodeMode = false
    @Published var isBarcodeScanning = false

    // MARK: - Geiger Search State
    @Published var isGeigerSearching = false
    @Published var geigerCurrentRssi: Double = 0.0
    @Published var geigerPeakRssi: Double = 0.0
    @Published var geigerProximity: Double = 0.0
    @Published var geigerReadCount = 0
    @Published var geigerReadRate: Double = 0.0
    @Published var selectedTagEpc: String?
    @Published var geigerTargetEpc: String = ""

    // MARK: - Battery State
    @Published var batteryLevel = 0
    @Published var isCharging = false

    // MARK: - Settings
    @Published var powerLevel: Double = 30.0
    @Published var session: Int = 1
    @Published var target: Int = 0
    @Published var enableBeep = true
    @Published var enableVibrate = true

    // MARK: - Trigger State
    @Published var triggerPressed = false

    // MARK: - Navigation State
    @Published var selectedTab = 0

    private let rfidManager = RfidManager.shared
    private var inventoryStartTime: Date?
    private var elapsedTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var lastTagReadTime: Date?
    private var geigerRssiTimeoutTimer: Timer?
    private var lastGeigerReadTime: Date?
    private var geigerReadsInInterval: Int = 0
    private var geigerRateTimer: Timer?

    // MARK: - Scanner Operations

    func startScan() {
        guard !isScanning else { return }
        discoveredReaders.removeAll()
        isScanning = true
        errorMessage = nil

        rfidManager.startScan(delegate: self)
    }

    func stopScan() {
        rfidManager.stopScan()
        isScanning = false
    }

    func connect(to reader: RfidReader) {
        guard !isConnecting else { return }
        isConnecting = true
        showConnectionOverlay = true
        connectionStatus = "Connecting..."
        errorMessage = nil

        rfidManager.connect(to: reader, delegate: self)
    }

    func disconnect() {
        rfidManager.disconnect()
        connectedReader = nil
        connectionStatus = "Not Connected"
        isInventoryRunning = false
    }

    // MARK: - Inventory Operations

    func startInventory() {
        guard connectedReader != nil, !isInventoryRunning else { return }

        isInventoryRunning = true
        errorMessage = nil // Clear any previous error
        startElapsedTimer()

        rfidManager.startInventory(delegate: self)
    }

    func stopInventory() {
        rfidManager.stopInventory()
        isInventoryRunning = false
        stopElapsedTimer()
    }

    func clearTags() {
        tags.removeAll()
        barcodes.removeAll()
        uniqueTagCount = 0
        totalReadCount = 0
        readRate = 0
    }

    // MARK: - Barcode Operations

    func startBarcodeScanning() {
        guard connectedReader != nil, !isBarcodeScanning else { return }

        isBarcodeScanning = true
        errorMessage = nil
        startElapsedTimer()

        rfidManager.startBarcodeScan(delegate: self)
    }

    func stopBarcodeScanning() {
        rfidManager.stopBarcodeScan()
        isBarcodeScanning = false
        stopElapsedTimer()
    }

    // MARK: - Configuration

    func applyConfiguration() {
        let rfidTarget = RfidTarget(rawValue: target) ?? .A
        rfidManager.configure()
            .powerLevel(Int(powerLevel * 10)) // Convert dBm to internal format
            .session(session)
            .target(rfidTarget)
            .apply(delegate: self)
    }

    // MARK: - Battery Monitoring

    func startBatteryMonitoring() {
        rfidManager.startBatteryMonitoring(delegate: self)
    }

    func stopBatteryMonitoring() {
        rfidManager.stopBatteryMonitoring()
    }

    // MARK: - Trigger Support

    func enableTriggerSupport() {
        rfidManager.enableTrigger(delegate: self)
    }

    func disableTriggerSupport() {
        rfidManager.disableTrigger()
    }

    // MARK: - Geiger Search Operations

    func startGeigerSearch(targetEpc: String) {
        guard connectedReader != nil, !isGeigerSearching else { return }

        // Reset Geiger state
        geigerCurrentRssi = 0.0
        geigerPeakRssi = 0.0
        geigerProximity = 0.0
        geigerReadCount = 0
        geigerReadRate = 0.0
        geigerReadsInInterval = 0
        lastGeigerReadTime = Date()
        errorMessage = nil

        isGeigerSearching = true

        // Start rate calculation timer
        startGeigerRateTimer()

        rfidManager.startGeigerSearch(targetEpc: targetEpc, delegate: self)
    }

    func stopGeigerSearch() {
        rfidManager.stopGeigerSearch()
        isGeigerSearching = false
        stopGeigerTimers()
        resetGeigerRssi()
    }

    private func startGeigerRateTimer() {
        geigerRateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.geigerReadRate = Double(self.geigerReadsInInterval)
                self.geigerReadsInInterval = 0
            }
        }
    }

    private func stopGeigerTimers() {
        geigerRssiTimeoutTimer?.invalidate()
        geigerRssiTimeoutTimer = nil
        geigerRateTimer?.invalidate()
        geigerRateTimer = nil
    }

    private func resetGeigerRssi() {
        geigerCurrentRssi = 0.0
        geigerProximity = 0.0
    }

    private func scheduleGeigerRssiTimeout() {
        geigerRssiTimeoutTimer?.invalidate()
        geigerRssiTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resetGeigerRssi()
            }
        }
    }

    // MARK: - Timer Management

    private func startElapsedTimer() {
        inventoryStartTime = Date()
        elapsedTime = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.inventoryStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Feedback

    private func playBeepSound() {
        guard enableBeep else { return }
        AudioServicesPlaySystemSound(1057) // Standard beep
    }

    private func triggerHapticFeedback() {
        guard enableVibrate else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func provideFeedback() {
        // Rate-limit feedback to avoid overwhelming
        let now = Date()
        if let lastTime = lastTagReadTime, now.timeIntervalSince(lastTime) < 0.1 {
            return
        }
        lastTagReadTime = now

        playBeepSound()
        triggerHapticFeedback()
    }
}


// MARK: - RfidScanDelegate

extension RfidViewModel: @preconcurrency RfidScanDelegate {
    func onReaderDiscovered(_ reader: RfidReader) {
        if !discoveredReaders.contains(where: { $0.id == reader.id }) {
            discoveredReaders.append(reader)
        }
    }

    func onScanError(_ error: RfidError) {
        errorMessage = error.description
        isScanning = false
    }
}

// MARK: - RfidConnectionDelegate

extension RfidViewModel: @preconcurrency RfidConnectionDelegate {
    func onConnecting() {
        connectionStatus = "Connecting..."
    }

    func onConnected(_ reader: RfidReader) {
        connectionStatus = "Connected - Initializing..."
    }

    func onReaderReady(_ reader: RfidReader) {
        connectedReader = reader
        connectionStatus = "Connected to \(reader.name)"
        isConnecting = false
        showConnectionOverlay = false
        stopScan()
        discoveredReaders.removeAll() // Clear discovered devices after connecting
        startBatteryMonitoring()
        enableTriggerSupport() // Enable trigger key for start/stop inventory
        applyConfiguration()
        selectedTab = 1 // Navigate to Inventory tab
    }

    func onConnectionFailed(_ error: RfidError) {
        errorMessage = "Connection failed: \(error.description)"
        connectionStatus = "Connection Failed"
        isConnecting = false
        showConnectionOverlay = false
        connectedReader = nil
    }

    func onDisconnected(_ reader: RfidReader?, error: RfidError?) {
        connectedReader = nil
        connectionStatus = "Disconnected: \(error?.description ?? "User requested")"
        isInventoryRunning = false
    }
}

// MARK: - RfidInventoryDelegate

extension RfidViewModel: @preconcurrency RfidInventoryDelegate {
    func onTagRead(_ tag: RfidTag) {
        if let index = tags.firstIndex(where: { $0.epc == tag.epc }) {
            tags[index] = tag
        } else {
            tags.append(tag)
            provideFeedback() // Only beep/vibrate for new tags
        }
        totalReadCount += 1
        uniqueTagCount = tags.count
    }

    func onInventoryRound(_ stats: RfidInventoryStats) {
        readRate = Int(stats.readRate)
    }

    func onInventoryStopped(_ reason: RfidStopReason) {
        isInventoryRunning = false
    }

    func onInventoryError(_ error: RfidError) {
        errorMessage = "Inventory error: \(error.description)"
        isInventoryRunning = false
    }
}

// MARK: - RfidConfigurationDelegate

extension RfidViewModel: @preconcurrency RfidConfigurationDelegate {
    func onConfigured() {
        // Configuration applied successfully
    }

    func onConfigurationFailed(_ error: RfidError) {
        errorMessage = "Configuration failed: \(error.description)"
    }
}

// MARK: - BatteryDelegate

extension RfidViewModel: @preconcurrency BatteryDelegate {
    func onBatteryUpdate(_ info: BatteryInfo) {
        batteryLevel = info.level
        isCharging = info.isCharging
    }

    func onBatteryError(_ error: RfidError) {
        errorMessage = "Battery error: \(error.description)"
    }
}

// MARK: - TriggerDelegate

extension RfidViewModel: @preconcurrency TriggerDelegate {
    func onTriggerStateChanged(_ pressed: Bool) {
        triggerPressed = pressed

        // Toggle inventory or geiger search based on trigger state
        if pressed {
            // Trigger pressed - start operation if not running
            if selectedTab == 1 && connectedReader != nil {
                // On Inventory tab - check mode
                if isBarcodeMode {
                    if !isBarcodeScanning {
                        startBarcodeScanning()
                    }
                } else {
                    if !isInventoryRunning {
                        startInventory()
                    }
                }
            } else if selectedTab == 3 && !isGeigerSearching && connectedReader != nil {
                // On Geiger Search tab - start search if EPC is set
                let epc = geigerTargetEpc.trimmingCharacters(in: .whitespacesAndNewlines)
                if !epc.isEmpty {
                    startGeigerSearch(targetEpc: epc)
                }
            }
        } else {
            // Trigger released - stop operation if running
            if isInventoryRunning {
                stopInventory()
            }
            if isBarcodeScanning {
                stopBarcodeScanning()
            }
            if isGeigerSearching {
                stopGeigerSearch()
            }
        }
    }
}

// MARK: - RfidGeigerDelegate

extension RfidViewModel: @preconcurrency RfidGeigerDelegate {
    func onSearchStarted() {
        // Search has started successfully
    }

    func onProximityUpdate(_ stats: RfidGeigerStats) {
        geigerCurrentRssi = stats.currentRssi
        geigerPeakRssi = stats.peakRssi
        geigerProximity = Double(stats.proximity)
        geigerReadCount = stats.readCount
        geigerReadsInInterval += 1

        // Schedule RSSI timeout reset
        scheduleGeigerRssiTimeout()
    }

    func onSearchStopped(_ reason: RfidStopReason) {
        isGeigerSearching = false
        stopGeigerTimers()
    }

    func onSearchError(_ error: RfidError) {
        errorMessage = "Search error: \(error.description)"
        isGeigerSearching = false
        stopGeigerTimers()
    }
}

// MARK: - BarcodeScanDelegate

extension RfidViewModel: @preconcurrency BarcodeScanDelegate {
    func onBarcodeScanned(_ data: BarcodeData) {
        if !barcodes.contains(where: { $0.barcode == data.barcode }) {
            barcodes.append(data)
            provideFeedback() // Beep for new barcode
        }
        totalReadCount += 1
        uniqueTagCount = barcodes.count
    }

    func onStatisticsUpdate(_ stats: BarcodeStats) {
        // Update rate based on stats if needed
    }

    // Note: onScanError is satisfied by RfidScanDelegate implementation above
}
