import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: RfidViewModel
    @State private var showingApplyConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                // Reader Info Section
                readerInfoSection

                // Power Settings
                powerSection

                // Inventory Settings
                inventorySection

                // Apply Button
                applySection
            }
            .navigationTitle("Settings")
            .alert(isPresented: $showingApplyConfirmation) {
                Alert(
                    title: Text("Apply Configuration"),
                    message: Text("This will apply the current settings to the connected reader."),
                    primaryButton: .default(Text("Apply")) {
                        viewModel.applyConfiguration()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var readerInfoSection: some View {
        Section(header: Text("Reader Information")) {
            if let reader = viewModel.connectedReader {
                HStack {
                    Text("Device")
                    Spacer()
                    Text(reader.name)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Text("Connected")
                        .foregroundColor(.green)
                }

                HStack {
                    Text("Battery")
                    Spacer()
                    Text("\(viewModel.batteryLevel)%")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No reader connected")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var powerSection: some View {
        Section(header: Text("RF Power")) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Power Level")
                    Spacer()
                    Text("\(viewModel.powerLevel, specifier: "%.1f") dBm")
                        .foregroundColor(.secondary)
                }

                Slider(value: $viewModel.powerLevel, in: 0...32, step: 0.5)
            }

            HStack {
                Text("Max Power")
                Spacer()
                Text("32.0 dBm")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var inventorySection: some View {
        Section(header: Text("Inventory Configuration")) {
            Picker("Session", selection: $viewModel.session) {
                Text("S0").tag(0)
                Text("S1").tag(1)
                Text("S2").tag(2)
                Text("S3").tag(3)
            }

            Picker("Target", selection: $viewModel.target) {
                Text("A").tag(0)
                Text("B").tag(1)
                Text("A/B Toggle").tag(2)
            }
        }
    }

    private var applySection: some View {
        Section {
            Button(action: {
                showingApplyConfirmation = true
            }) {
                HStack {
                    Spacer()
                    Text("Apply Configuration")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(viewModel.connectedReader == nil)
        }
    }
}
