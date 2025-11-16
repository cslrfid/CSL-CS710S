import Foundation
import CoreBluetooth
import CSL_CS710S_Core

/// Main API entry point for RFID operations
/// This class provides a clean Swift interface to the CSL-CS710S reader
public final class RfidManager: NSObject {

    // MARK: - Singleton

    /// Shared instance (singleton pattern)
    public static let shared = RfidManager()

    // MARK: - Properties

    private var coreBridge: CoreBridge!

    private var configuration: RfidConfiguration = .default
    private var connectedReader: RfidReader?
    private var pendingConnectionReader: RfidReader?

    // Operation states
    private var isScanning = false
    private var isInventorying = false
    private var isSearching = false
    private var isBatteryMonitoring = false
    private var isBarcodeScanActive = false

    // Delegates
    private weak var scanDelegate: RfidScanDelegate?
    private weak var connectionDelegate: RfidConnectionDelegate?
    private weak var inventoryDelegate: RfidInventoryDelegate?
    private weak var geigerDelegate: RfidGeigerDelegate?
    private weak var configurationDelegate: RfidConfigurationDelegate?
    private weak var batteryDelegate: BatteryDelegate?
    private weak var barcodeScanDelegate: BarcodeScanDelegate?
    private weak var triggerDelegate: TriggerDelegate?

    // Inventory tracking
    private var tagCounts: [String: Int] = [:]
    private var totalReads: Int = 0
    private var inventoryStartTime: Date?
    private var lastRateCheckTime: Date?
    private var lastRateCheckReads: Int = 0

    // Geiger search tracking
    private var targetEpc: String = ""
    private var peakRssi: Double = -90.0
    private var currentRssi: Double = -90.0
    private var geigerReadCount: Int = 0
    private var searchStartTime: Date?

    // Barcode tracking
    private var scannedBarcodes: Set<String> = []
    private var totalBarcodeScans: Int = 0
    private var barcodeStartTime: Date?

    // Timers
    private var batteryTimer: Timer?
    private var inventoryTimer: Timer?

    // MARK: - Initialization

    private override init() {
        super.init()
        initializeSDK()
    }

    private func initializeSDK() {
        // Initialize the Core SDK bridge
        coreBridge = CoreBridge()

        // Set up callbacks from Core SDK
        setupCoreBridgeCallbacks()
    }

    private func setupCoreBridgeCallbacks() {
        // Scanning callbacks
        coreBridge.onDeviceDiscovered = { [weak self] peripheral, name, rssi in
            guard let self = self, self.isScanning else { return }

            let reader = RfidReader(
                name: name,
                address: peripheral.identifier.uuidString,
                rssi: Double(rssi),
                peripheral: peripheral
            )
            self.scanDelegate?.onReaderDiscovered(reader)
        }

        // Connection callbacks
        // Note: onConnected is not used anymore since we handle connection synchronously
        // in performCompleteConnection, but we keep it for delegate protocol compliance
        coreBridge.onConnected = { _ in
            // Connection is handled synchronously in performCompleteConnection
        }

        coreBridge.onConnectionFailed = { [weak self] _ in
            self?.pendingConnectionReader = nil
            self?.connectionDelegate?.onConnectionFailed(
                RfidError(message: "Failed to connect to device", type: .CONNECTION_FAILED)
            )
        }

        coreBridge.onDisconnected = { [weak self] _ in
            guard let self = self else { return }
            let reader = self.connectedReader
            self.connectedReader = nil
            self.isInventorying = false
            self.isSearching = false
            self.connectionDelegate?.onDisconnected(reader, error: nil)
        }

        // Tag reading callback
        coreBridge.onTagReceived = { [weak self] cslTag in
            guard let self = self else { return }

            if self.isInventorying {
                self.processInventoryTag(cslTag)
            } else if self.isSearching {
                self.processGeigerTag(cslTag)
            }
        }

        // Battery callback
        coreBridge.onBatteryUpdate = { [weak self] level in
            guard let self = self, self.isBatteryMonitoring else { return }
            let info = BatteryInfo(level: level, isCharging: false)
            self.batteryDelegate?.onBatteryUpdate(info)
        }

        // Trigger callback
        coreBridge.onTriggerChanged = { [weak self] pressed in
            self?.triggerDelegate?.onTriggerStateChanged(pressed)
        }

        // Barcode callback
        coreBridge.onBarcodeReceived = { [weak self] barcode in
            guard let self = self, self.isBarcodeScanActive else { return }
            self.processBarcodeData(barcode)
        }
    }

    // MARK: - Public API - Scanning

    /// Start scanning for RFID readers
    public func startScan(delegate: RfidScanDelegate) {
        guard !isScanning else {
            delegate.onScanError(RfidError(message: "Already scanning", type: .SCAN_FAILED))
            return
        }

        self.scanDelegate = delegate
        self.isScanning = true

        coreBridge.startScan()
    }

    /// Stop scanning for readers
    public func stopScan() {
        isScanning = false
        coreBridge.stopScan()
        scanDelegate = nil
    }

    /// Check if currently scanning
    public var scanning: Bool {
        return isScanning
    }

    // MARK: - Public API - Connection

    /// Connect to a specific reader
    public func connect(to reader: RfidReader, delegate: RfidConnectionDelegate) {
        self.connectionDelegate = delegate
        self.pendingConnectionReader = reader

        delegate.onConnecting()

        // Stop scanning first (matching CSLDeviceTV.m behavior)
        stopScan()

        // Connect to device
        if let peripheral = reader.peripheral {
            // Perform connection and initialization on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.performCompleteConnection(reader: reader, peripheral: peripheral)
            }
        } else {
            delegate.onConnectionFailed(RfidError(message: "Invalid peripheral", type: .CONNECTION_FAILED))
        }
    }

    /// Perform the complete connection sequence matching CSLDeviceTV.m
    private func performCompleteConnection(reader: RfidReader, peripheral: CBPeripheral) {
        // Step 1: Connect to device
        coreBridge.connect(peripheral)

        // Step 2: Poll for CONNECTED status with 5 second timeout
        let timeoutIterations = 5000 // 5 seconds at 1ms intervals
        var connected = false

        for _ in 0..<timeoutIterations {
            if coreBridge.connectionStatus == STATUS.CONNECTED {
                connected = true
                break
            }
            Thread.sleep(forTimeInterval: 0.001)
        }

        guard connected else {
            DispatchQueue.main.async { [weak self] in
                self?.pendingConnectionReader = nil
                self?.connectionDelegate?.onConnectionFailed(
                    RfidError(message: "Connection timeout - failed to connect within 5 seconds", type: .TIMEOUT)
                )
            }
            return
        }

        // Notify that we're connected but still initializing
        DispatchQueue.main.async { [weak self] in
            self?.connectionDelegate?.onConnected(reader)
        }

        // Step 3: Reload settings from user defaults
        coreBridge.reloadSettings()

        // Step 4: Set device name
        coreBridge.setDeviceName(reader.name)

        // Step 5: Perform complete reader initialization (firmware info, OEM data, frequencies, etc.)
        let initSuccess = coreBridge.performCompleteReaderInitialization()

        guard initSuccess else {
            DispatchQueue.main.async { [weak self] in
                self?.pendingConnectionReader = nil
                self?.connectionDelegate?.onConnectionFailed(
                    RfidError(message: "Reader initialization failed", type: .CONFIGURATION_FAILED)
                )
            }
            return
        }

        // Step 6: Mark connection as complete
        self.connectedReader = reader
        self.pendingConnectionReader = nil

        DispatchQueue.main.async { [weak self] in
            self?.connectionDelegate?.onReaderReady(reader)
        }
    }

    /// Disconnect from current reader
    public func disconnect() {
        stopAllOperations()
        coreBridge.disconnect()
        connectedReader = nil
    }

    /// Check if connected to a reader
    public var isConnected: Bool {
        return coreBridge.isConnected
    }

    /// Get the currently connected reader
    public var currentReader: RfidReader? {
        return connectedReader
    }

    // MARK: - Public API - Configuration

    /// Get current configuration
    public var currentConfiguration: RfidConfiguration {
        return configuration
    }

    /// Apply configuration to reader
    public func configure(_ config: RfidConfiguration, delegate: RfidConfigurationDelegate) {
        guard isConnected else {
            delegate.onConfigurationFailed(RfidError(message: "Not connected to reader", type: .NOT_CONNECTED))
            return
        }

        self.configurationDelegate = delegate
        self.configuration = config

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var success = true

            // Apply power level (convert from internal format to dBm)
            let powerDbm = Double(config.powerLevel) / 10.0
            success = success && self.coreBridge.configurePower(powerDbm)

            // Apply session and target
            let session = SESSION(rawValue: UInt8(config.session)) ?? .S1
            let target = TARGET(rawValue: UInt8(config.target.rawValue)) ?? .A

            success = success && self.coreBridge.configureQuerySettings(
                target: target,
                session: session,
                select: QUERYSELECT.ALL
            )

            DispatchQueue.main.async {
                if success {
                    delegate.onConfigured()
                } else {
                    delegate.onConfigurationFailed(
                        RfidError(message: "Failed to apply configuration", type: .CONFIGURATION_FAILED)
                    )
                }
            }
        }
    }

    /// Fluent configuration builder
    public func configure() -> ConfigurationBuilder {
        return ConfigurationBuilder(manager: self)
    }

    // MARK: - Public API - Inventory

    /// Start tag inventory operation
    public func startInventory(delegate: RfidInventoryDelegate) {
        guard isConnected else {
            delegate.onInventoryError(RfidError(message: "Not connected to reader", type: .NOT_CONNECTED))
            return
        }

        guard !isInventorying else {
            delegate.onInventoryError(RfidError(message: "Inventory already in progress", type: .INVENTORY_FAILED))
            return
        }

        self.inventoryDelegate = delegate
        self.isInventorying = true
        self.tagCounts.removeAll()
        self.totalReads = 0
        self.inventoryStartTime = Date()
        self.lastRateCheckTime = Date()
        self.lastRateCheckReads = 0

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Apply standard inventory configuration
            self.coreBridge.applyStandardConfiguration()

            // Start inventory
            let success = self.coreBridge.startInventory()

            if !success {
                DispatchQueue.main.async {
                    self.isInventorying = false
                    delegate.onInventoryError(
                        RfidError(message: "Failed to start inventory", type: .INVENTORY_FAILED)
                    )
                }
            }
        }

        // Start stats update timer
        startInventoryStatsTimer()
    }

    /// Stop inventory operation
    public func stopInventory() {
        guard isInventorying else { return }

        isInventorying = false
        coreBridge.stopInventory()
        stopInventoryStatsTimer()

        DispatchQueue.main.async { [weak self] in
            self?.inventoryDelegate?.onInventoryStopped(.USER_STOPPED)
        }
    }

    /// Check if inventory is active
    public var inventorying: Bool {
        return isInventorying
    }

    private func processInventoryTag(_ cslTag: CSLBleTag) {
        let epcString = cslTag.epc ?? ""
        guard !epcString.isEmpty else { return }

        // Calculate RSSI
        let rssiValue = Double(cslTag.rssi)

        // Track tag count
        let count = (tagCounts[epcString] ?? 0) + 1
        tagCounts[epcString] = count
        totalReads += 1

        let tag = RfidTag(
            epc: epcString,
            rssi: rssiValue,
            count: count,
            phase: 0,
            channel: 0,
            timestamp: Date().timeIntervalSince1970
        )

        inventoryDelegate?.onTagRead(tag)
    }

    private func startInventoryStatsTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.inventoryTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.updateInventoryStats()
            }
        }
    }

    private func stopInventoryStatsTimer() {
        inventoryTimer?.invalidate()
        inventoryTimer = nil
    }

    private func updateInventoryStats() {
        guard let startTime = inventoryStartTime, isInventorying else { return }

        let elapsed = Int64(Date().timeIntervalSince(startTime) * 1000)

        // Calculate read rate based on actual tag reads over the last interval
        var readRate = 0.0
        if let lastCheck = lastRateCheckTime {
            let intervalSeconds = Date().timeIntervalSince(lastCheck)
            if intervalSeconds > 0 {
                let readsInInterval = totalReads - lastRateCheckReads
                readRate = Double(readsInInterval) / intervalSeconds
            }
        }

        // Update rate tracking for next calculation
        lastRateCheckTime = Date()
        lastRateCheckReads = totalReads

        let stats = RfidInventoryStats(
            uniqueTagCount: tagCounts.count,
            totalReads: totalReads,
            readRate: readRate,
            elapsedTimeMs: elapsed
        )

        inventoryDelegate?.onInventoryRound(stats)
    }

    // MARK: - Public API - Geiger Search

    /// Start Geiger search for a specific tag
    public func startGeigerSearch(targetEpc: String, memoryBank: Int = 1, delegate: RfidGeigerDelegate) {
        guard isConnected else {
            delegate.onSearchError(RfidError(message: "Not connected to reader", type: .NOT_CONNECTED))
            return
        }

        guard !isSearching else {
            delegate.onSearchError(RfidError(message: "Search already in progress", type: .UNKNOWN))
            return
        }

        self.geigerDelegate = delegate
        self.targetEpc = targetEpc
        self.isSearching = true
        self.peakRssi = -90.0
        self.currentRssi = -90.0
        self.geigerReadCount = 0
        self.searchStartTime = Date()

        delegate.onSearchStarted()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Apply tag search configuration
            self.coreBridge.applyTagSearchConfiguration()

            // Start tag search with EPC mask
            let maskLength = UInt32(targetEpc.count * 4) // bits
            let success = self.coreBridge.startTagSearch(
                epc: targetEpc,
                maskPointer: 32, // Start after CRC and PC
                maskLength: maskLength
            )

            if !success {
                DispatchQueue.main.async {
                    self.isSearching = false
                    delegate.onSearchError(
                        RfidError(message: "Failed to start tag search", type: .UNKNOWN)
                    )
                }
            }
        }
    }

    /// Stop Geiger search
    public func stopGeigerSearch() {
        guard isSearching else { return }

        isSearching = false
        coreBridge.stopInventory()

        DispatchQueue.main.async { [weak self] in
            self?.geigerDelegate?.onSearchStopped(.USER_STOPPED)
        }
    }

    /// Check if Geiger search is active
    public var searching: Bool {
        return isSearching
    }

    private func processGeigerTag(_ cslTag: CSLBleTag) {
        guard cslTag.epc == targetEpc else { return }

        // Extract RSSI
        currentRssi = Double(cslTag.rssi)

        // Calculate proximity (0-100) based on RSSI
        // CS710 RSSI scaling: (rawRSSI / 75.0) * 100.0
        let proximity = min(100, max(0, Int((currentRssi / 75.0) * 100.0)))

        geigerReadCount += 1

        if currentRssi > peakRssi {
            peakRssi = currentRssi
        }

        let elapsed = Int64((searchStartTime?.timeIntervalSinceNow ?? 0) * -1000)

        let stats = RfidGeigerStats(
            targetEpc: targetEpc,
            currentRssi: currentRssi,
            peakRssi: peakRssi,
            readCount: geigerReadCount,
            proximity: proximity,
            elapsedTimeMs: elapsed
        )

        geigerDelegate?.onProximityUpdate(stats)
    }

    // MARK: - Public API - Battery Monitoring

    /// Start battery level monitoring
    public func startBatteryMonitoring(delegate: BatteryDelegate) {
        self.batteryDelegate = delegate
        self.isBatteryMonitoring = true

        // Get initial battery level
        let level = coreBridge.batteryLevel
        let info = BatteryInfo(level: level, isCharging: false)
        delegate.onBatteryUpdate(info)

        // Battery updates come automatically via delegate callback every 5 seconds
    }

    /// Stop battery monitoring
    public func stopBatteryMonitoring() {
        isBatteryMonitoring = false
        batteryDelegate = nil
    }

    // MARK: - Public API - Barcode Scanning

    /// Start barcode scanning
    public func startBarcodeScan(delegate: BarcodeScanDelegate) {
        guard isConnected else {
            delegate.onScanError(RfidError(message: "Not connected to reader", type: .NOT_CONNECTED))
            return
        }

        self.barcodeScanDelegate = delegate
        self.isBarcodeScanActive = true
        self.scannedBarcodes.removeAll()
        self.totalBarcodeScans = 0
        self.barcodeStartTime = Date()

        // Enable barcode scanner on reader
        let success = coreBridge.startBarcodeScan()
        if !success {
            isBarcodeScanActive = false
            delegate.onScanError(RfidError(message: "Failed to start barcode scanner", type: .UNKNOWN))
        }
    }

    /// Stop barcode scanning
    public func stopBarcodeScan() {
        isBarcodeScanActive = false
        coreBridge.stopBarcodeScan()
        barcodeScanDelegate = nil
    }

    /// Check if barcode scanning is active
    public var barcodeScanActive: Bool {
        return isBarcodeScanActive
    }

    private func processBarcodeData(_ cslBarcode: CSLReaderBarcode) {
        let barcodeString = cslBarcode.barcodeValue ?? ""
        guard !barcodeString.isEmpty else { return }

        totalBarcodeScans += 1
        scannedBarcodes.insert(barcodeString)

        let data = BarcodeData(barcode: barcodeString)
        let elapsed = Int64((barcodeStartTime?.timeIntervalSinceNow ?? 0) * -1000)
        let stats = BarcodeStats(
            totalScans: totalBarcodeScans,
            uniqueBarcodes: scannedBarcodes.count,
            elapsedTimeMs: elapsed
        )

        barcodeScanDelegate?.onBarcodeScanned(data)
        barcodeScanDelegate?.onStatisticsUpdate(stats)
    }

    // MARK: - Public API - Trigger Support

    /// Enable hardware trigger button
    public func enableTrigger(delegate: TriggerDelegate, autoInventory: Bool = false) {
        self.triggerDelegate = delegate
    }

    /// Disable hardware trigger button
    public func disableTrigger() {
        triggerDelegate = nil
    }

    // MARK: - Utility Methods

    /// Stop all active operations
    public func stopAllOperations() {
        if isInventorying { stopInventory() }
        if isSearching { stopGeigerSearch() }
        if isBatteryMonitoring { stopBatteryMonitoring() }
        if isBarcodeScanActive { stopBarcodeScan() }
        if isScanning { stopScan() }
    }

    /// Release all resources
    public func release() {
        stopAllOperations()
        disconnect()
    }

    deinit {
        release()
    }
}

// MARK: - Configuration Builder

/// Fluent builder for RfidConfiguration
public class ConfigurationBuilder {
    private var config: RfidConfiguration
    private weak var manager: RfidManager?

    internal init(manager: RfidManager) {
        self.manager = manager
        self.config = manager.currentConfiguration
    }

    /// Set power level (0-320, representing 0.0-32.0 dBm)
    public func powerLevel(_ value: Int) -> ConfigurationBuilder {
        config.powerLevel = value
        return self
    }

    /// Set inventory session (0-3)
    public func session(_ value: Int) -> ConfigurationBuilder {
        config.session = value
        return self
    }

    /// Set target flag
    public func target(_ value: RfidTarget) -> ConfigurationBuilder {
        config.target = value
        return self
    }

    /// Set inventory mode
    public func inventoryMode(_ value: RfidInventoryMode) -> ConfigurationBuilder {
        config.inventoryMode = value
        return self
    }

    /// Set Q value (0-15)
    public func qValue(_ value: Int) -> ConfigurationBuilder {
        config.qValue = value
        return self
    }

    /// Enable/disable beep on tag read
    public func enableBeep(_ value: Bool) -> ConfigurationBuilder {
        config.enableBeep = value
        return self
    }

    /// Enable/disable vibration on tag read
    public func enableVibrate(_ value: Bool) -> ConfigurationBuilder {
        config.enableVibrate = value
        return self
    }

    /// Apply the configuration
    public func apply(delegate: RfidConfigurationDelegate) {
        manager?.configure(config, delegate: delegate)
    }
}
