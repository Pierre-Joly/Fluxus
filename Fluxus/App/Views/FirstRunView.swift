import SwiftUI

struct FirstRunView: View {
    @ObservedObject var viewModel: FluxusViewModel

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome to Fluxus")
                            .font(.largeTitle)
                            .fontWeight(.semibold)

                        Text("Review safety guidance before enabling automatic cleanup.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        SafetyRow(text: "Targets start empty: add only folders you are sure can be cleaned.")
                        SafetyRow(text: "Use Simulation first to inspect the exact file list.")
                        SafetyRow(text: "Automatic cleanup stays disabled until you explicitly save and apply.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Important", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Toggle(isOn: $viewModel.acknowledgmentChecked) {
                    Text("I understand")
                        .font(.headline)
                }

                HStack {
                    Button("Continue") {
                        viewModel.completeFirstRunAcknowledgement()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.acknowledgmentChecked)

                    Spacer()
                }

                if !viewModel.statusMessage.isEmpty {
                    StatusBannerView(
                        message: viewModel.statusMessage,
                        isError: viewModel.statusIsError,
                        onDismiss: viewModel.clearStatus
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(26)
            .frame(maxWidth: 760)
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}

private struct SafetyRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
        }
    }
}
