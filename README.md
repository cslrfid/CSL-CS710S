# CSL-CS710S

![Platform](https://img.shields.io/badge/platform-iOS%2013.0%2B-blue.svg)
![Language](https://img.shields.io/badge/language-Objective--C-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Version](https://img.shields.io/badge/version-1.12.0-red.svg)

CocoaPod Framework for CSL CS710S RFID SDK - A comprehensive iOS framework for interfacing with CSL CS710 RFID handheld readers via Bluetooth Low Energy (BLE).

## Overview

The CSL-CS710S SDK provides a complete solution for iOS applications to communicate with CSL CS710 series RFID readers. It implements the EPC Class 1 Gen 2 RFID protocol and offers comprehensive functionality for:

- **RFID Tag Operations**: Inventory, read, write, lock, and kill operations
- **BLE Communication**: Low-level Bluetooth LE device discovery and connection management
- **Tag Access Control**: Memory bank operations (RESERVED, EPC, TID, USER)
- **Barcode Scanning**: Integrated barcode scanner support
- **Temperature Tags**: Magnus S3 temperature tag support
- **Regional Compliance**: Support for FCC, ETSI, JP, MY, TW, CN, and other regional frequency standards
- **Advanced Features**: Impinj extensions, tag focusing, FastID, multi-bank operations

## Requirements

- iOS 13.0 or later
- Xcode 12.0 or later
- CocoaPods 1.10 or later

## Installation

### Swift Package Manager (Recommended)

Swift Package Manager is Apple's official dependency manager and the recommended installation method.

**Xcode 13+:**

1. In Xcode, go to `File` > `Add Packages...`
2. Enter the repository URL: `https://github.com/cslrfid/CSL-CS710S.git`
3. Select version `1.12.0` or later
4. Click `Add Package`

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/cslrfid/CSL-CS710S.git", from: "1.12.0")
]
```

### CocoaPods (Supported until December 2026)

> **Note**: CocoaPods will become read-only in December 2026. We recommend migrating to Swift Package Manager for future compatibility.

Add the following line to your `Podfile`:

```ruby
pod 'CSL-CS710S'
```

Then run:

```bash
pod install
```

### Manual Integration

1. Clone this repository
2. Open the `.xcworkspace` file in Xcode
3. Build the framework for your target platform
4. Add the built framework to your project

## Quick Start

### 1. Initialize the SDK

```objective-c
#import <CSL_CS710S/CSL_CS710S.h>

// Get the singleton instance
CSLRfidAppEngine *appEngine = [CSLRfidAppEngine sharedAppEngine];
CSLBleReader *reader = appEngine.reader;
```

### 2. Scan and Connect to Reader

```objective-c
// Set up delegates
reader.delegate = self;
reader.scanDelegate = self;

// Start scanning for devices
[reader startScanDevice];

// Connect to discovered device
[reader connectDevice:peripheral];
```

### 3. Configure Reader Settings

```objective-c
// Set power level (0-30 dBm)
appEngine.settings.power = 30;

// Set session and target
appEngine.settings.session = S1;
appEngine.settings.target = ToggleAB;

// Set link profile for optimal performance
appEngine.settings.linkProfile = MID_323;

// Apply configurations
[CSLReaderConfigurations setConfigurationsForTags];
[CSLReaderConfigurations setAntennaPortsAndPowerForTags:YES];
```

### 4. Start Tag Inventory

```objective-c
// Start continuous inventory
[reader startTagInventory];

// Implement delegate to receive tag data
- (void)didReceiveTagResponsePacket:(CSLBleTag *)tag {
    NSLog(@"EPC: %@, RSSI: %d", tag.EPC, tag.rssi);
}

// Stop inventory
[reader stopTagInventory];
```

### 5. Read/Write Tag Operations

```objective-c
// Read tag memory
[reader setParametersForTagAccess];
[reader TAGACC_BANK:USER acc_bank2:RESERVED];
[reader TAGACC_PTR:0x00];
[reader TAGACC_CNT:4 secondBank:0];
[reader sendHostCommandRead];

// Write tag memory
[reader TAGACC_BANK:USER acc_bank2:RESERVED];
[reader TAGACC_PTR:0x00];
[reader setTAGWRDAT:TAGWRDAT_0 data_word:0x1234 data_offset:0];
[reader sendHostCommandWrite];
```

## Architecture

The SDK is organized into two primary modules:

### CSLReader - Low-level Communication Layer
- **CSLBleInterface**: Core Bluetooth LE manager for device discovery and connection
- **CSLBleReader**: Main RFID reader class implementing command/response protocol
- **CSLBleReader+AccessControl**: Tag access operations (read/write/lock/kill)
- **CSLBlePacket**: BLE packet structure and encoding
- **CSLCircularQueue**: Thread-safe circular buffer for packet queuing
- **CSLBleTag**: Tag data model (EPC, RSSI, phase, PC bits)

### CSLModel - Business Logic Layer
- **CSLRfidAppEngine**: Singleton managing reader lifecycle and settings
- **CSLReaderSettings**: Application settings and configurations
- **CSLReaderInfo**: Reader hardware metadata
- **CSLReaderFrequency**: Regional frequency table generator
- **CSLReaderConfigurations**: Static configuration utilities
- **CSLReaderBattery**: Battery monitoring
- **CSLReaderBarcode**: Barcode scanner integration
- **CSLTemperatureTagSettings**: Temperature tag configurations

## Key Features

### Reader Model Support
- **CS710**: Full support with E710 register-based commands
- **CS108**: Legacy support with CS108 command protocol

### Link Profiles
Optimized link profiles for different use cases:
- **Range-focused**: `RANGE_DRM`, `RANGE_THROUGHPUT_DRM`
- **Throughput-focused**: `MAX_THROUGHPUT`
- **Balanced modes**: `MID_323`, `MID_344`, `MID_103`, and 30+ additional profiles
- **CS710S firmware 2.1.2+**: Extended link profile support

### Regional Frequency Support
Automatic frequency table generation based on OEM data:
- FCC (United States)
- ETSI (Europe)
- JP (Japan)
- MY (Malaysia)
- TW (Taiwan)
- CN (China)
- And more...

### Advanced Tag Operations
- Multi-bank read operations
- Selective tag filtering with mask operations
- Tag focusing (Impinj extension)
- FastID support for M4 tags
- BlockWrite mode configuration
- Tag locking and kill operations

## Delegate Methods

### CSLBleReaderDelegate

```objective-c
// Called when a tag is read
- (void)didReceiveTagResponsePacket:(CSLBleTag *)tag;

// Called when tag access operation completes
- (void)didReceiveTagAccessData:(CSLBleTag *)tag;

// Called when barcode is scanned
- (void)didReceiveBarcodeData:(CSLReaderBarcode *)barcode;

// Called when connection status changes
- (void)didInterfaceChangeConnectStatus:(CSLBleInterface *)sender;

// Called when trigger key is pressed
- (void)didTriggerKeyChangedState:(BOOL)state;

// Called when battery level changes
- (void)didReceiveBatteryLevelIndicator:(int)batteryPercentage;
```

### CSLBleScanDelegate

```objective-c
// Called when a new device is discovered
- (void)deviceListWasUpdated:(CBPeripheral *)deviceDiscovered;

// Called when device connection succeeds
- (void)didConnectToDevice:(CBPeripheral *)deviceConnected;

// Called when device disconnects
- (void)didDisconnectDevice:(CBPeripheral *)deviceDisconnected;

// Called when device connection fails
- (void)didFailedToConnect:(CBPeripheral *)deviceFailedToConnect;
```

## Settings Persistence

Settings are automatically saved to and loaded from `NSUserDefaults`:

```objective-c
// Save current settings
[appEngine saveSettingsToUserDefaults];

// Reload settings
[appEngine reloadSettingsFromUserDefaults];

// Temperature tag settings
[appEngine saveTemperatureTagSettingsToUserDefaults];
[appEngine reloadTemperatureTagSettingsFromUserDefaults];
```

## Thread Safety

- Command operations are synchronous with timeout mechanisms
- Critical sections are protected with `@synchronized` blocks
- Packet decoding runs on background threads
- **Important**: Reader operations are NOT thread-safe at the command level - always wait for completion before issuing the next command

## Version History

### 1.12.0 (Current)
- **Added Swift Package Manager support** - Future-proof distribution method
- Dual distribution support - Works with both CocoaPods and Swift Package Manager
- Reorganized header structure - All public headers now in `include/` directory
- Fixed enum naming conflict (ALERTCONDITION) for better system compatibility
- Updated framework imports to use module syntax
- **Updated .gitignore** - Added Swift Package Manager build artifacts exclusion

### 1.11.0
- Removed MQTTClient dependency - Streamlined for pure RFID operations
- Streamlined codebase for pure RFID operations

### 1.10.0
- Bug fix on `getRfidFwVersionNumber`
- Improved firmware version detection

### 1.9.0
- Added support for link profiles of CS710S RFID firmware 2.1.2+
- Extended link profile options (30+ profiles)

### 1.8.0
- Updated device scanning functionality
- Improved BLE connection stability

### 1.7.0
- Implemented regional and frequency configurations for CS710S
- Enhanced OEM data handling

## Building from Source

```bash
# Clone the repository
git clone https://github.com/cslrfid/CSL-CS710S.git
cd CSL-CS710S

# Open the workspace (NOT the .xcodeproj)
open CSL-CS710S.xcworkspace

# Build via command line
xcodebuild -workspace CSL-CS710S.xcworkspace \
           -scheme CSL-CS710S \
           -configuration Release

# Validate podspec
pod spec lint CSL-CS710S.podspec
```

## Example Usage Scenarios

### Scenario 1: Basic Inventory with Filtering

```objective-c
// Enable pre-filter for specific EPC mask
appEngine.settings.prefilterIsEnabled = YES;
appEngine.settings.prefilterBank = EPC;
appEngine.settings.prefilterMask = @"E2801170";
appEngine.settings.prefilterOffset = 32;

[CSLReaderConfigurations setConfigurationsForTags];
[reader startTagInventory];
```

### Scenario 2: Temperature Tag Reading

```objective-c
// Configure for temperature tags
appEngine.temperatureSettings.sensorType = MAGNUSS3;
appEngine.temperatureSettings.unit = YES; // Celsius
appEngine.temperatureSettings.isTemperatureAlertEnabled = YES;
appEngine.temperatureSettings.temperatureAlertLowerLimit = 2.0;
appEngine.temperatureSettings.temperatureAlertUpperLimit = 8.0;

[CSLReaderConfigurations setConfigurationsForTemperatureTags];
[CSLReaderConfigurations setAntennaPortsAndPowerForTemperatureTags:YES];
[reader startTagInventory];
```

### Scenario 3: Tag Write with Access Password

```objective-c
// Set access password
[reader TAGACC_ACCPWD:0x12345678];

// Configure write operation
[reader TAGACC_BANK:USER acc_bank2:RESERVED];
[reader TAGACC_PTR:0x00];
[reader TAGACC_CNT:4 secondBank:0];

// Write data
for (int i = 0; i < 4; i++) {
    [reader setTAGWRDAT:TAGWRDAT_0 + i data_word:writeData[i] data_offset:i];
}

[reader sendHostCommandWrite];
```

## Troubleshooting

### Connection Issues
- Ensure Bluetooth is enabled on the iOS device
- Check that the reader is powered on and within range
- Verify the reader firmware version is compatible
- Try disconnecting and reconnecting

### Inventory Performance
- Adjust power level based on environment (reduce power in dense tag environments)
- Select appropriate link profile for your use case
- Enable tag focusing for faster singulation
- Configure Q value based on tag population

### Regional Frequency Issues
- Ensure correct region is selected in settings
- Read OEM data before configuring frequencies
- Verify reader hardware supports the selected region

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Manufacturer

**Convergence Systems Limited**
Leading provider of RFID solutions and hardware

---

**Note**: This SDK is designed for professional RFID applications. Ensure compliance with local regulations regarding RF emissions and frequency usage.
