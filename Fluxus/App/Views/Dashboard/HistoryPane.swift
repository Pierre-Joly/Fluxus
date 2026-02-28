import SwiftUI

struct HistoryPane: View {
    @ObservedObject var viewModel: FluxusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Refresh") {
                    viewModel.refreshHistoryFromDisk()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBusy)
                Spacer()
            }

            if let output = viewModel.historyOutput {
                HStack(spacing: 12) {
                    MetricPill(title: "Processed", value: "\(output.processedCount)")
                    MetricPill(title: "Trashed", value: "\(output.trashedCount)")
                    MetricPill(title: "Archived", value: "\(output.archivedCount)")
                    MetricPill(title: "Pruned", value: "\(output.prunedDirectoryCount)")
                    MetricPill(title: "Errors", value: "\(output.errorCount)")
                    MetricPill(title: "Size", value: viewModel.formatBytes(output.totalBytes))
                }

                GroupBox("Top Folders") {
                    if output.topFolders.isEmpty {
                        Text("No folder stats available.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(output.topFolders.prefix(8)) { folder in
                                HStack {
                                    Text(folder.folder)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text("\(folder.count) files")
                                        .foregroundStyle(.secondary)
                                    Text(viewModel.formatBytes(folder.bytes))
                                        .monospacedDigit()
                                }
                                .font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !output.errors.isEmpty {
                    GroupBox("Recent Errors") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(output.errors.prefix(6).enumerated()), id: \.offset) { _, error in
                                Text("• \(error.path): \(error.message)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No history report")
                        .font(.title3)
                    Text("Run cleanup once to populate this section.")
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
