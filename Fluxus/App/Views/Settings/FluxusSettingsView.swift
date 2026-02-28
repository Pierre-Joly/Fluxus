import SwiftUI

struct FluxusSettingsView: View {
    @ObservedObject var viewModel: FluxusViewModel

    var body: some View {
        TabView {
            GeneralSettingsPane(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AboutSettingsPane()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 560, minHeight: 360)
    }
}
