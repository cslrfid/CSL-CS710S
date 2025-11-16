import SwiftUI
import CSL_CS710S_Library

struct ScannerView: View {
    @ObservedObject var viewModel: RfidViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                connectionStatusView

                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                // Scan Button
                scanButton

                // Device List
                deviceListView

                Spacer()
            }
            .padding()
            .navigationTitle("RFID Scanner")
            .navigationBarItems(trailing: batteryIndicator)
        }
    }

    private var batteryIndicator: some View {
        Group {
            if viewModel.connectedReader != nil {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isCharging ? "battery.100.bolt" : batteryIcon)
                        .foregroundColor(batteryColor)
                    Text("\(viewModel.batteryLevel)%")
                        .font(.caption)
                }
            } else {
                EmptyView()
            }
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

    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(viewModel.connectedReader != nil ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            Text(viewModel.connectionStatus)
                .font(.subheadline)

            Spacer()

            if viewModel.connectedReader != nil {
                Button("Disconnect") {
                    viewModel.disconnect()
                }
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var scanButton: some View {
        Button(action: {
            if viewModel.isScanning {
                viewModel.stopScan()
            } else {
                viewModel.startScan()
            }
        }) {
            HStack {
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 5)
                }
                Text(viewModel.isScanning ? "Stop Scanning" : "Scan for Devices")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(viewModel.connectedReader != nil ? Color.gray : Color.blue)
            .cornerRadius(10)
        }
        .disabled(viewModel.connectedReader != nil)
    }

    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Discovered Devices")
                .font(.headline)

            if viewModel.discoveredReaders.isEmpty {
                Text("No devices found. Tap 'Scan for Devices' to search.")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.discoveredReaders, id: \.id) { reader in
                            deviceRow(reader)
                        }
                    }
                }
            }
        }
    }

    private func deviceRow(_ reader: RfidReader) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reader.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text("RSSI: \(Int(reader.rssi))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Connect") {
                viewModel.connect(to: reader)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .disabled(viewModel.isConnecting)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
