import SwiftUI

struct GeneralSettingsPane: View {
    @ObservedObject var viewModel: FluxusViewModel

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appearance")
                            .font(.headline)
                        Text("Choose how Fluxus should render its interface.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)

                Picker("Theme", selection: $viewModel.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Current") {
                    Text(currentAppearanceDescription)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("System follows your macOS appearance. Black forces dark and White forces light.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var currentAppearanceDescription: String {
        switch viewModel.appearance {
        case .system:
            return "Following macOS"
        case .black:
            return "Dark appearance"
        case .white:
            return "Light appearance"
        }
    }
}
