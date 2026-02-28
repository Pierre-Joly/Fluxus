import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: FluxusViewModel

    var body: some View {
        if viewModel.hasAcknowledgedWarning {
            MainDashboardView(viewModel: viewModel)
        } else {
            FirstRunView(viewModel: viewModel)
        }
    }
}
