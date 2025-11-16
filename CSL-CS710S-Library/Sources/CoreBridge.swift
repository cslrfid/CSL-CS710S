import Foundation
import CoreBluetooth
import CSL_CS710S_Core

/// Bridge layer between Swift wrapper and Objective-C Core SDK
/// Implements Core SDK delegate protocols and forwards events to Swift callbacks
internal class CoreBridge: NSObject {

    let appEngine: CSLRfidAppEngine
    let bleReader: CSLBleReader

    // Callbacks for Swift layer
    var onDeviceDiscovered: ((CBPeripheral, String, Int) -> Void)?
    var onConnected: ((CBPeripheral) -> Void)?
    var onDisconnected: ((CBPeripheral) -> Void)?
    var onConnectionFailed: ((CBPeripheral) -> Void)?
    var onStatusChanged: (() -> Void)?

    var onTagReceived: ((CSLBleTag) -> Void)?
    var onTriggerChanged: ((Bool) -> Void)?
    var onBatteryUpdate: ((Int) -> Void)?
    var onBarcodeReceived: ((CSLReaderBarcode) -> Void)?

    override init() {
        // Get shared app engine instance
        self.appEngine = CSLRfidAppEngine.shared()
        self.bleReader = appEngine.reader

        super.init()

        // Set self as delegate for all SDK callbacks
        bleReader.scanDelegate = self
        bleReader.delegate = self
        bleReader.readerDelegate = self
    }

    deinit {
        bleReader.scanDelegate = nil
        bleReader.delegate = nil
        bleReader.readerDelegate = nil
    }

    // MARK: - Scanning

    func startScan() {
        bleReader.startScanDevice()
    }

    func stopScan() {
        bleReader.stopScanDevice()
    }

    /// Get discovered devices from the device list
    var discoveredDevices: [(peripheral: CBPeripheral, name: String, rssi: Int)] {
        var devices: [(CBPeripheral, String, Int)] = []
        let deviceList = bleReader.bleDeviceList as? [CBPeripheral] ?? []
        let nameList = bleReader.deviceListName as? [String] ?? []

        for (index, peripheral) in deviceList.enumerated() {
            let name = index < nameList.count ? nameList[index] : peripheral.name ?? "Unknown"
            devices.append((peripheral, name, -60)) // RSSI not stored in list
        }
        return devices
    }

    // MARK: - Connection

    func connect(_ peripheral: CBPeripheral) {
        bleReader.connectDevice(peripheral)
    }

    func disconnect() {
        bleReader.disconnectDevice()
    }

    var isConnected: Bool {
        return bleReader.connectStatus == STATUS.CONNECTED ||
               bleReader.connectStatus == STATUS.TAG_OPERATIONS
    }

    var connectionStatus: STATUS {
        return bleReader.connectStatus
    }

    var readerModel: READERTYPE {
        return bleReader.readerModelNumber
    }

    // MARK: - Configuration

    func configurePower(_ level: Double) -> Bool {
        return bleReader.setPower(level)
    }

    func configureQuerySettings(
        target: TARGET,
        session: SESSION,
        select: QUERYSELECT
    ) -> Bool {
        return bleReader.setQueryConfigurations(
            target,
            querySession: session,
            querySelect: select
        )
    }

    func setLinkProfile(_ profile: LINKPROFILE) -> Bool {
        return bleReader.setLinkProfile(profile)
    }

    func applyStandardConfiguration() {
        // Apply standard configurations like the official demo does
        CSLReaderConfigurations.setAntennaPortsAndPowerForTags(false)
        CSLReaderConfigurations.setConfigurationsForClearAllSelectionsAndMultibanks()
        CSLReaderConfigurations.setConfigurationsForTags(false)
    }

    func applyTagSearchConfiguration() {
        CSLReaderConfigurations.setAntennaPortsAndPowerForTagSearch(false)
    }

    // MARK: - Inventory

    func startInventory() -> Bool {
        // Clear buffer before starting
        bleReader.filteredBuffer.removeAllObjects()

        // Start inventory based on reader model
        if readerModel == READERTYPE.CS710 {
            // CS710S uses specific compact inventory
            return bleReader.e710StartCompactInventory()
        } else {
            return bleReader.startInventory()
        }
    }

    func stopInventory() {
        bleReader.stopInventory()
    }

    /// Get the tag rate from the reader (reads per second)
    var tagRate: Int {
        return Int(bleReader.readerTagRate)
    }

    /// Get the unique tag count from the reader
    var uniqueTagCount: Int {
        return Int(bleReader.uniqueTagCount)
    }

    // MARK: - Tag Search (Geiger Mode)

    func startTagSearch(epc: String, maskPointer: UInt16, maskLength: UInt32) -> Bool {
        // Convert EPC string to hex data
        guard let maskData = CSLBleReader.convertHexString(toData: epc) else {
            return false
        }

        // Use EPC memory bank for tag search
        return bleReader.startTagSearch(MEMORYBANK.EPC, maskPointer: maskPointer, maskLength: maskLength, maskData: maskData)
    }

    // MARK: - Battery

    var batteryLevel: Int {
        return Int(appEngine.readerInfo.batteryPercentage)
    }

    var batteryInfo: CSLReaderBattery? {
        return bleReader.batteryInfo
    }

    // MARK: - Barcode

    func startBarcodeScan() -> Bool {
        return bleReader.startBarcodeReading()
    }

    func stopBarcodeScan() {
        bleReader.stopBarcodeReading()
    }

    // MARK: - Reader Info

    var deviceName: String {
        return bleReader.deviceName ?? "Unknown"
    }

    func setDeviceName(_ name: String) {
        bleReader.deviceName = name
    }

    var firmwareVersion: String {
        return appEngine.readerInfo.rfidFirmwareVersion ?? ""
    }

    var btFirmwareVersion: String {
        return appEngine.readerInfo.btFirmwareVersion ?? ""
    }

    var pcbBoardVersion: String {
        return appEngine.readerInfo.pcbBoardVersion ?? ""
    }

    // MARK: - Settings Persistence

    func saveSettings() {
        appEngine.saveSettingsToUserDefaults()
    }

    func reloadSettings() {
        appEngine.reloadSettingsFromUserDefaults()
    }

    var settings: CSLReaderSettings {
        return appEngine.settings
    }

    var readerInfo: CSLReaderInfo {
        return appEngine.readerInfo
    }

    // MARK: - Complete Reader Initialization (matching CSLDeviceTV.m)

    /// Complete reader initialization sequence matching the official CSL demo app
    func performCompleteReaderInitialization() -> Bool {
        // Wait for connection to stabilize
        Thread.sleep(forTimeInterval: 0.5)

        // Power on RFID and barcode modules
        bleReader.barcodeReader(false)
        _ = bleReader.power(onRfid: false)
        bleReader.barcodeReader(true)
        _ = bleReader.power(onRfid: true)

        // Get firmware versions
        var btFwVersion: NSString?
        if bleReader.getBtFirmwareVersion(&btFwVersion) {
            appEngine.readerInfo.btFirmwareVersion = btFwVersion as String?
        }

        var slVersion: NSString?
        if bleReader.getSilLabIcVersion(&slVersion) {
            appEngine.readerInfo.siLabICFirmwareVersion = slVersion as String?
        }

        var rfidBoardSn: NSString?
        if bleReader.getRfidBrdSerialNumber(&rfidBoardSn) {
            appEngine.readerInfo.deviceSerialNumber = rfidBoardSn as String?
        }

        // For non-CS710S readers, get PCB board version
        if bleReader.readerModelNumber != READERTYPE.CS710 {
            var pcbVersion: NSString?
            if bleReader.getPcBBoardVersion(&pcbVersion) {
                appEngine.readerInfo.pcbBoardVersion = pcbVersion as String?
                if let versionString = pcbVersion as String?, let versionNumber = Double(versionString) {
                    bleReader.batteryInfo.setPcbVersion(versionNumber)
                }
            }
        }

        // Send abort command to clear any pending operations
        bleReader.sendAbortCommand()

        // Get RFID firmware version
        var rfidFwVersion: NSString?
        if bleReader.getRfidFwVersionNumber(&rfidFwVersion) {
            appEngine.readerInfo.rfidFirmwareVersion = rfidFwVersion as String?
        }

        // Set app version
        if let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let buildVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String {
            appEngine.readerInfo.appVersion = "v\(shortVersion) Build \(buildVersion)"
        }

        // Read OEM data and initialize frequency tables
        initializeOEMDataAndFrequencies()

        // Start battery auto-reporting for CS710S
        if bleReader.readerModelNumber == READERTYPE.CS710 {
            bleReader.startBatteryAutoReporting()
        } else {
            // Check BT firmware version to determine CS108 vs CS463
            if let btFw = appEngine.readerInfo.btFirmwareVersion, btFw.count >= 5 {
                if btFw.hasPrefix("3") {
                    // BT firmware version >= v3 means CS463
                    bleReader.readerModelNumber = READERTYPE.CS463
                } else {
                    bleReader.readerModelNumber = READERTYPE.CS108
                    bleReader.startBatteryAutoReporting()
                }
            }
        }

        // Stop trigger key auto-reporting (events are triggered automatically by Core SDK)
        bleReader.stopTriggerKeyAutoReporting()

        // Apply reader configurations
        CSLReaderConfigurations.setReaderRegionAndFrequencies()
        CSLReaderConfigurations.setAntennaPortsAndPowerForTags(true)
        CSLReaderConfigurations.setConfigurationsForClearAllSelectionsAndMultibanks()
        CSLReaderConfigurations.setConfigurationsForTags()

        return true
    }

    /// Initialize OEM data and frequency tables based on reader model
    private func initializeOEMDataAndFrequencies() {
        var oemData: UInt32 = 0

        if bleReader.readerModelNumber == READERTYPE.CS710 {
            // CS710S OEM data addresses
            if bleReader.readOEMData(bleReader, atAddr: 0xEF98, forData: &oemData) {
                appEngine.readerInfo.countryCode = oemData
            }

            if bleReader.readOEMData(bleReader, atAddr: 0xEFAC, forData: &oemData) {
                appEngine.readerInfo.specialCountryVerison = oemData
            }

            if bleReader.readOEMData(bleReader, atAddr: 0xEFB0, forData: &oemData) {
                appEngine.readerInfo.freqModFlag = oemData
            }

            if bleReader.readOEMData(bleReader, atAddr: 0xEFB4, forData: &oemData) {
                appEngine.readerInfo.modelCode = oemData
            }

            // Get current country enum and frequency index
            var countryEnum: UInt32 = 0
            var freqIndex: UInt32 = 0
            bleReader.e710GetCountryEnum(bleReader, forData: &countryEnum)
            bleReader.e710GetFrequencyChannelIndex(bleReader, forData: &freqIndex)

            // Initialize frequency table for CS710S
            appEngine.readerRegionFrequency = CSLReaderFrequency(
                oemDataForCS710S: appEngine.readerInfo.countryCode,
                specialCountryVerison: appEngine.readerInfo.specialCountryVerison,
                freqModFlag: appEngine.readerInfo.freqModFlag,
                modelCode: appEngine.readerInfo.modelCode
            )

            // Check if we need to save current configuration
            if let regionFreq = appEngine.readerRegionFrequency,
               let regionKey = appEngine.settings.region,
               regionFreq.tableOfFrequencies[regionKey] == nil,
               countryEnum != 0 {
                // No previous valid configurations were saved, save current configuration
                if let allRegionList = regionFreq.allRegionList as? [String], Int(countryEnum) < allRegionList.count {
                    appEngine.settings.region = allRegionList[Int(countryEnum)]
                }
                if let hoppingStatus = regionFreq.countryEnumToHoppingStatus as? [NSNumber],
                   Int(countryEnum) < hoppingStatus.count {
                    let isFixed = hoppingStatus[Int(countryEnum)].intValue != 0
                    appEngine.settings.channel = isFixed ? String(freqIndex) : "0"
                    appEngine.readerInfo.isFxied = isFixed ? 1 : 0
                }
                appEngine.saveSettingsToUserDefaults()
            }

        } else {
            // CS108 OEM data addresses
            bleReader.readOEMData(bleReader, atAddr: 0x00000002, forData: &oemData)
            appEngine.readerInfo.countryCode = oemData

            bleReader.readOEMData(bleReader, atAddr: 0x0000008E, forData: &oemData)
            appEngine.readerInfo.specialCountryVerison = oemData

            bleReader.readOEMData(bleReader, atAddr: 0x0000008F, forData: &oemData)
            appEngine.readerInfo.freqModFlag = oemData

            bleReader.readOEMData(bleReader, atAddr: 0x000000A4, forData: &oemData)
            appEngine.readerInfo.modelCode = oemData

            bleReader.readOEMData(bleReader, atAddr: 0x0000009D, forData: &oemData)
            appEngine.readerInfo.isFxied = oemData

            // Initialize frequency table for CS108
            appEngine.readerRegionFrequency = CSLReaderFrequency(
                oemData: appEngine.readerInfo.countryCode,
                specialCountryVerison: appEngine.readerInfo.specialCountryVerison,
                freqModFlag: appEngine.readerInfo.freqModFlag,
                modelCode: appEngine.readerInfo.modelCode,
                isFixed: appEngine.readerInfo.isFxied
            )

            // Check if stored region is valid
            if let regionFreq = appEngine.readerRegionFrequency,
               let regionKey = appEngine.settings.region,
               regionFreq.tableOfFrequencies[regionKey] == nil {
                // Reset to default region and channel
                if let regionList = regionFreq.regionList as? [String], !regionList.isEmpty {
                    appEngine.settings.region = regionList[0]
                }
                appEngine.settings.channel = "0"
                appEngine.saveSettingsToUserDefaults()
            }
        }
    }
}


// MARK: - CSLBleScanDelegate

extension CoreBridge: CSLBleScanDelegate {

    func deviceListWasUpdated(_ deviceDiscovered: CBPeripheral) {
        let name = deviceDiscovered.name ?? "Unknown"
        // Get RSSI if available (approximation)
        let rssi = -60 // Default RSSI since not directly available

        DispatchQueue.main.async { [weak self] in
            self?.onDeviceDiscovered?(deviceDiscovered, name, rssi)
        }
    }

    func didConnect(toDevice deviceConnected: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            self?.onConnected?(deviceConnected)
        }
    }

    func didDisconnectDevice(_ deviceDisconnected: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            self?.onDisconnected?(deviceDisconnected)
        }
    }

    func didFailed(toConnect deviceFailedToConnect: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionFailed?(deviceFailedToConnect)
        }
    }
}

// MARK: - CSLBleInterfaceDelegate

extension CoreBridge: CSLBleInterfaceDelegate {

    func didInterfaceChangeConnectStatus(_ sender: CSLBleInterface) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChanged?()
        }
    }
}

// MARK: - CSLBleReaderDelegate

extension CoreBridge: CSLBleReaderDelegate {

    func didReceiveTagResponsePacket(_ sender: CSLBleReader, tagReceived tag: CSLBleTag) {
        DispatchQueue.main.async { [weak self] in
            self?.onTagReceived?(tag)
        }
    }

    func didTriggerKeyChangedState(_ sender: CSLBleReader, keyState state: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onTriggerChanged?(state)
        }
    }

    func didReceiveBatteryLevelIndicator(_ sender: CSLBleReader, batteryPercentage battPct: Int32) {
        DispatchQueue.main.async { [weak self] in
            self?.onBatteryUpdate?(Int(battPct))
        }
    }

    func didReceiveBarcodeData(_ sender: CSLBleReader, scannedBarcode barcode: CSLReaderBarcode) {
        DispatchQueue.main.async { [weak self] in
            self?.onBarcodeReceived?(barcode)
        }
    }

    func didReceiveTagAccessData(_ sender: CSLBleReader, tagReceived tag: CSLBleTag) {
        // Forward tag access data (read/write operations)
        DispatchQueue.main.async { [weak self] in
            self?.onTagReceived?(tag)
        }
    }
}
