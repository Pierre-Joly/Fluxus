import SwiftUI

struct SimulationPane: View {
    @ObservedObject var viewModel: FluxusViewModel
    @Binding var selectedCandidateID: CandidateRecord.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Run Simulation") {
                    Task { await viewModel.runSimulationNow() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)

                Spacer()
            }

            if let output = viewModel.simulationOutput {
                HStack(spacing: 12) {
                    MetricPill(title: "Candidates", value: "\(output.candidateCount)")
                    MetricPill(title: "Total Size", value: viewModel.formatBytes(output.totalBytes))
                    MetricPill(title: "Roots", value: "\(output.roots.count)")
                }

                Table(viewModel.simulationCandidates, selection: $selectedCandidateID, sortOrder: $viewModel.sortOrder) {
                    TableColumn("Path", value: \.path) { item in
                        Text(item.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    TableColumn("Size", value: \.sizeBytes) { item in
                        Text(viewModel.formatBytes(item.sizeBytes))
                    }
                    TableColumn("Modified", value: \.modifiedAtEpoch) { item in
                        Text(item.modifiedAt)
                    }
                    TableColumn("Root", value: \.rootName)
                    TableColumn("Action", value: \.actionLabel)
                }
                .onChange(of: viewModel.sortOrder) { _ in
                    viewModel.applySortOrder()
                }
                .frame(minHeight: 360)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No simulation report yet")
                        .font(.title3)
                    Text("Run a simulation to preview files before cleanup.")
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
