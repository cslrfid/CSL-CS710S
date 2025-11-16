# CSL CS710S QuickStart Demo

A SwiftUI demo application showcasing RFID operations using the CSL-CS710S-Library Swift wrapper.

## Features

- **Device Scanning**: Discover nearby CSL RFID readers (CS108/CS710S)
- **Connection Management**: Connect/disconnect from readers
- **Tag Inventory**: Real-time tag scanning with count and read rate
- **Settings Configuration**: Adjust power level, session, and target parameters
- **Battery Monitoring**: Monitor reader battery status

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.3+
- CSL CS108 or CS710S RFID reader

## Project Structure

```
CSL-CS710S/                         # Root repository
├── CSL-CS710S-Core.xcodeproj      # Core SDK Xcode project
├── CSL-CS710S-Library.xcodeproj   # Swift Library Xcode project
├── QuickStartDemo.xcodeproj       # Demo app Xcode project
├── CSL-CS710S.xcworkspace         # Unified workspace
└── QuickStartDemo/
    └── QuickStartDemo/
        ├── QuickStartDemoApp.swift      # App entry point
        ├── ContentView.swift            # Main tab view
        ├── Info.plist                   # Bluetooth permissions
        ├── README.md                    # This file
        ├── ViewModels/
        │   └── RfidViewModel.swift      # Main RFID operations ViewModel
        └── Views/
            ├── ScannerView.swift        # Device discovery & connection
            ├── InventoryView.swift      # Tag inventory operations
            └── SettingsView.swift       # Reader configuration
```

## Setup

### Using the Workspace (Recommended)

1. Open the main CSL-CS710S workspace:
   ```bash
   cd /path/to/CSL-CS710S
   open CSL-CS710S.xcworkspace
   ```

2. The workspace includes:
   - **CSL-CS710S-Core.xcodeproj** - Objective-C Core SDK
   - **CSL-CS710S-Library.xcodeproj** - Swift wrapper framework
   - **QuickStartDemo.xcodeproj** - This demo app

3. Select the `QuickStartDemo` scheme in Xcode

4. Select your physical iOS device as the run destination (BLE requires physical device)

5. Build and run (⌘R)

### Opening the Project Directly

1. Open the QuickStartDemo project from the root:
   ```bash
   cd /path/to/CSL-CS710S
   open QuickStartDemo.xcodeproj
   ```

2. The project automatically references the CSL-CS710S Swift package for the `CSL-CS710S-Library` dependency

3. Build and run on your iOS device

## Usage

### 1. Scanner Tab

- Tap "Scan for Devices" to discover nearby RFID readers
- Select a reader from the list and tap "Connect"
- Wait for initialization to complete

### 2. Inventory Tab

- Once connected, tap "Start" to begin tag inventory
- Tags are displayed with EPC, RSSI, and read count
- Monitor real-time statistics (unique count, total reads, rate)
- Tap "Stop" to end inventory
- Use "Clear" to reset the tag list

### 3. Settings Tab

- Adjust RF power level (0-32 dBm)
- Select inventory session (S0-S3)
- Choose target (A, B, or Toggle)
- Tap "Apply Configuration" to send settings to reader

## Bluetooth Permissions

The app requires Bluetooth permissions. The Info.plist includes:

- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`

Users will be prompted to grant Bluetooth access on first launch.

## Architecture

The demo follows MVVM architecture:

- **Model**: Uses `CSL-CS710S-Library` types (RfidTag, RfidReader, etc.)
- **ViewModel**: `RfidViewModel` manages all RFID operations and state
- **View**: SwiftUI views for user interface

### ViewModel Features

- `@Published` properties for reactive UI updates
- Delegate pattern implementation for SDK callbacks
- Centralized state management
- Error handling and display

## Comparison with Android QuickStart

This iOS demo mirrors the functionality of the Android QuickStart app:

| Feature | Android | iOS |
|---------|---------|-----|
| UI Framework | Jetpack Compose | SwiftUI |
| Architecture | MVVM + StateFlow | MVVM + ObservableObject |
| BLE Stack | Android BLE | CoreBluetooth |
| SDK Wrapper | csl-rfid-android-sdk | CSL-CS710S-Library |

## License

This demo is provided as part of the CSL-CS710S iOS SDK.

Copyright (c) Convergence Systems Limited. All rights reserved.
