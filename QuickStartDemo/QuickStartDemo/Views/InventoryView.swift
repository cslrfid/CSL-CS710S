import SwiftUI
import CSL_CS710S_Library

struct InventoryView: View {
    @ObservedObject var viewModel: RfidViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Mode Toggle
                modeToggle

                // Stats Bar
                statsBar

                // Control Buttons
                controlButtons

                // Tag/Barcode List
                if viewModel.isBarcodeMode {
                    barcodeListView
                } else {
                    tagListView
                }
            }
            .padding()
            .navigationTitle("Inventory")
            .navigationBarItems(trailing: batteryStatusView)
        }
    }

    private var modeToggle: some View {
        Picker("Mode", selection: $viewModel.isBarcodeMode) {
            Text("RFID").tag(false)
            Text("Barcode").tag(true)
        }
        .pickerStyle(SegmentedPickerStyle())
        .disabled(viewModel.isInventoryRunning || viewModel.isBarcodeScanning)
    }

    private var statsBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                statItem(title: "Unique", value: "\(viewModel.isBarcodeMode ? viewModel.barcodes.count : viewModel.uniqueTagCount)")
                statItem(title: "Total", value: "\(viewModel.totalReadCount)")
                if !viewModel.isBarcodeMode {
                    statItem(title: "Rate", value: "\(viewModel.readRate)/s")
                }
            }

            if viewModel.isInventoryRunning || viewModel.isBarcodeScanning || viewModel.elapsedTime > 0 {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(formattedElapsedTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var formattedElapsedTime: String {
        let minutes = Int(viewModel.elapsedTime) / 60
        let seconds = Int(viewModel.elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                if viewModel.isBarcodeMode {
                    if viewModel.isBarcodeScanning {
                        viewModel.stopBarcodeScanning()
                    } else {
                        viewModel.startBarcodeScanning()
                    }
                } else {
                    if viewModel.isInventoryRunning {
                        viewModel.stopInventory()
                    } else {
                        viewModel.startInventory()
                    }
                }
            }) {
                HStack {
                    Image(systemName: isScanning ? "stop.fill" : "play.fill")
                    Text(isScanning ? "Stop" : "Start")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(viewModel.connectedReader == nil ? Color.gray : (isScanning ? Color.red : Color.green))
                .cornerRadius(10)
            }
            .disabled(viewModel.connectedReader == nil)

            Button(action: {
                viewModel.clearTags()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.blue)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 1)
                )
            }
            .disabled(isScanning)
        }
    }

    private var isScanning: Bool {
        viewModel.isBarcodeMode ? viewModel.isBarcodeScanning : viewModel.isInventoryRunning
    }

    private var tagListView: some View {
        VStack(alignment: .leading) {
            Text("Tags (\(viewModel.tags.count))")
                .font(.headline)

            if viewModel.connectedReader == nil {
                notConnectedView
            } else if viewModel.tags.isEmpty {
                emptyTagsView
            } else {
                tagList
            }
        }
    }

    private var notConnectedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Connect to a reader to start inventory")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTagsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tag")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No tags scanned yet")
                .foregroundColor(.secondary)
            Text("Tap 'Start' to begin inventory")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tagList: some View {
        List(viewModel.tags, id: \.epc) { tag in
            Button(action: {
                // Navigate to Geiger Search with this EPC
                viewModel.selectedTagEpc = tag.epc
                viewModel.selectedTab = 3 // Geiger Search tab
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tag.epc)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    HStack {
                        Label("\(Int(tag.rssi))", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        Text("Count: \(tag.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listStyle(.plain)
    }

    private var barcodeListView: some View {
        VStack(alignment: .leading) {
            Text("Barcodes (\(viewModel.barcodes.count))")
                .font(.headline)

            if viewModel.connectedReader == nil {
                notConnectedView
            } else if viewModel.barcodes.isEmpty {
                emptyBarcodeView
            } else {
                barcodeList
            }
        }
    }

    private var emptyBarcodeView: some View {
        VStack(spacing: 10) {
            Image(systemName: "barcode")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No barcodes scanned yet")
                .foregroundColor(.secondary)
            Text("Tap 'Start' to begin scanning")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var barcodeList: some View {
        List(viewModel.barcodes) { barcode in
            VStack(alignment: .leading, spacing: 4) {
                Text(barcode.barcode)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Text(formatTimestamp(barcode.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }

    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var batteryStatusView: some View {
        if viewModel.connectedReader != nil {
            HStack {
                Image(systemName: viewModel.isCharging ? "battery.100.bolt" : batteryIcon)
                    .foregroundColor(batteryColor)

                Text("\(viewModel.batteryLevel)%")
                    .font(.caption)

                if viewModel.isCharging {
                    Text("Charging")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
        }
    }

    private var batteryIcon: String {
        switch viewModel.batteryLevel {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        switch viewModel.batteryLevel {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}
