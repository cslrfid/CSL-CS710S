import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RfidViewModel()

    var body: some View {
        ZStack {
            TabView(selection: $viewModel.selectedTab) {
                ScannerView(viewModel: viewModel)
                    .tabItem {
                        Label("Scanner", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(0)

                InventoryView(viewModel: viewModel)
                    .tabItem {
                        Label("Inventory", systemImage: "list.bullet.rectangle")
                    }
                    .tag(1)

                GeigerSearchView(viewModel: viewModel)
                    .tabItem {
                        Label("Search", systemImage: "location.magnifyingglass")
                    }
                    .tag(3)

                SettingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
            .environmentObject(viewModel)

            // Connection overlay
            if viewModel.showConnectionOverlay {
                connectionOverlay
            }
        }
    }

    private var connectionOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))

                Text(viewModel.connectionStatus)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Please wait...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(Color(.systemGray5))
            .cornerRadius(20)
        }
    }
}
