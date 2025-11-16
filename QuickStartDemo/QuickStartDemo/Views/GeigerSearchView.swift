import SwiftUI
import CSL_CS710S_Library

// Custom shape for semi-circular gauge
struct SemiCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

struct GeigerSearchView: View {
    @ObservedObject var viewModel: RfidViewModel
    @FocusState private var isEpcFieldFocused: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Target EPC Input
                    epcInputSection

                    // Proximity Gauge
                    proximityGauge

                    // RSSI Display
                    rssiDisplay

                    // Stats Display
                    statsDisplay

                    // Search Button
                    searchButton
                }
                .padding()
            }
            .navigationTitle("Geiger Search")
            .navigationBarItems(trailing: batteryStatusView)
            .onAppear {
                // Pre-fill EPC if one was selected from inventory
                if let selectedEpc = viewModel.selectedTagEpc, !selectedEpc.isEmpty {
                    viewModel.geigerTargetEpc = selectedEpc
                    viewModel.selectedTagEpc = nil
                }
            }
            .onDisappear {
                // Stop search when leaving the view
                if viewModel.isGeigerSearching {
                    viewModel.stopGeigerSearch()
                }
            }
        }
    }

    private var epcInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target EPC")
                .font(.headline)

            TextField("Enter EPC to search", text: $viewModel.geigerTargetEpc)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .focused($isEpcFieldFocused)
                .disabled(viewModel.isGeigerSearching)
        }
    }

    private var proximityGauge: some View {
        VStack(spacing: 0) {
            ZStack {
                // Background semi-circular arc (left to right)
                SemiCircleShape()
                    .stroke(Color(.systemGray5), lineWidth: 25)
                    .frame(width: 220, height: 110)

                // Colored proximity arc
                SemiCircleShape()
                    .trim(from: 0, to: viewModel.geigerProximity / 100.0)
                    .stroke(
                        proximityGradient,
                        style: StrokeStyle(lineWidth: 25, lineCap: .round)
                    )
                    .frame(width: 220, height: 110)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.geigerProximity)

                // Proximity percentage in center
                VStack(spacing: 4) {
                    Text("\(Int(viewModel.geigerProximity))")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                    Text("Proximity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .offset(y: 20)
            }
            .frame(height: 160)
        }
        .padding(.vertical, 8)
    }

    private var proximityGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemGray4),
                Color.yellow,
                Color.orange,
                Color.red
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var proximityColor: Color {
        let proximity = viewModel.geigerProximity
        if proximity < 25 {
            return Color(.systemGray4)
        } else if proximity < 50 {
            return .yellow
        } else if proximity < 75 {
            return .orange
        } else {
            return .red
        }
    }

    private var rssiDisplay: some View {
        HStack(spacing: 30) {
            VStack(spacing: 4) {
                Text("Current RSSI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f", viewModel.geigerCurrentRssi))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("Peak RSSI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f", viewModel.geigerPeakRssi))
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var statsDisplay: some View {
        HStack(spacing: 20) {
            statItem(title: "Reads", value: "\(viewModel.geigerReadCount)")
            statItem(title: "Rate", value: String(format: "%.1f/s", viewModel.geigerReadRate))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var searchButton: some View {
        Button(action: {
            if viewModel.isGeigerSearching {
                viewModel.stopGeigerSearch()
            } else {
                startSearch()
            }
        }) {
            HStack {
                Image(systemName: viewModel.isGeigerSearching ? "stop.fill" : "magnifyingglass")
                Text(viewModel.isGeigerSearching ? "Stop Search" : "Search")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(viewModel.connectedReader == nil ? Color.gray : (viewModel.isGeigerSearching ? Color.red : Color.blue))
            .cornerRadius(10)
        }
        .disabled(viewModel.connectedReader == nil)
    }

    @ViewBuilder
    private var batteryStatusView: some View {
        if viewModel.connectedReader != nil {
            HStack {
                Image(systemName: viewModel.isCharging ? "battery.100.bolt" : batteryIcon)
                    .foregroundColor(batteryColor)

                Text("\(viewModel.batteryLevel)%")
                    .font(.caption)
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

    private func startSearch() {
        let epc = viewModel.geigerTargetEpc.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !epc.isEmpty else {
            viewModel.errorMessage = "Please enter a valid EPC"
            return
        }

        guard viewModel.connectedReader != nil else {
            viewModel.errorMessage = "Not connected to reader"
            return
        }

        isEpcFieldFocused = false
        viewModel.startGeigerSearch(targetEpc: epc)
    }
}

