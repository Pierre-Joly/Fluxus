import SwiftUI

struct OverviewPane: View {
    @ObservedObject var viewModel: FluxusViewModel
    let scheduleDateBinding: Binding<Date>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 16) {
                        Toggle("Enabled", isOn: $viewModel.config.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.large)

                        HStack(spacing: 8) {
                            Text("Run at")
                                .foregroundStyle(.secondary)
                            DatePicker(
                                "",
                                selection: scheduleDateBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .focusable(false)
                        }

                        Spacer(minLength: 0)

                        Label(
                            viewModel.launchAgentLoaded ? "Agent loaded" : "Agent not loaded",
                            systemImage: viewModel.launchAgentLoaded ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                        )
                        .foregroundStyle(viewModel.launchAgentLoaded ? .green : .secondary)
                    }
                }
            }.padding(.horizontal, 2)

            GroupBox("") {
                if viewModel.config.roots.isEmpty {
                    Text("No targets yet. Go to Targets to add folders and retention rules.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(viewModel.config.roots.count) target\(viewModel.config.roots.count == 1 ? "" : "s") configured")
                            .font(.subheadline.weight(.semibold))

                        ForEach(Array(viewModel.config.roots.prefix(3).indices), id: \.self) { index in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.config.roots[index].displayName)
                                        .font(.subheadline.weight(.medium))
                                    Text(viewModel.config.roots[index].displayPath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer(minLength: 0)
                                Text("\(viewModel.config.roots[index].retentionDays)d")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 2)
                        }

                        if viewModel.config.roots.count > 3 {
                            Text("+\(viewModel.config.roots.count - 3) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
