import AppKit
import SwiftUI

struct RulesPane: View {
    @ObservedObject var viewModel: FluxusViewModel
    @State private var selectedRootIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            archiveSection
            targetsSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            ensureSelectionIsValid()
        }
        .onChange(of: viewModel.config.roots.count) { _ in
            ensureSelectionIsValid()
        }
    }

    private var archiveSection: some View {
        GroupBox("Archive") {
            HStack(spacing: 8) {
                TextField(
                    "Archive folder (e.g. ~/Archive/Quarantine)",
                    text: $viewModel.config.archive.basePath
                )
                .textFieldStyle(.roundedBorder)

                Button("Choose…") {
                    chooseArchiveFolder()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var targetsSection: some View {
        GroupBox("Targets") {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        targetsListColumn
                            .frame(width: 250)
                            .frame(minHeight: 260)
                        targetDetailColumn
                            .frame(minWidth: 280, maxWidth: .infinity, minHeight: 260)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 12) {
                        targetsListColumn
                            .frame(maxWidth: .infinity, minHeight: 220)
                        targetDetailColumn
                            .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        addTarget()
                    } label: {
                        Label("Add Folder Target", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("add-folder-target-button")

                    Button(role: .destructive) {
                        removeSelectedTarget()
                    } label: {
                        Label("Remove Selected", systemImage: "minus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedRootIndex == nil)

                    Spacer(minLength: 0)

                    Text("\(viewModel.config.roots.count) target\(viewModel.config.roots.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var targetsListColumn: some View {
        GroupBox {
            if viewModel.config.roots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No targets configured")
                        .font(.headline)
                    Text("Add a folder target and set the maximum file age in days.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
            } else {
                List(selection: $selectedRootIndex) {
                    ForEach(Array(viewModel.config.roots.enumerated()), id: \.offset) { index, root in
                        TargetListRow(root: root)
                            .tag(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRootIndex = index
                            }
                            .accessibilityIdentifier("target-row-\(index)")
                            .contextMenu {
                                Button(role: .destructive) {
                                    removeTarget(at: index)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
                .accessibilityIdentifier("targets-list")
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var targetDetailColumn: some View {
        GroupBox {
            if let selectedRootIndex, viewModel.config.roots.indices.contains(selectedRootIndex) {
                TargetDetailEditor(
                    root: bindingForRoot(at: selectedRootIndex),
                    onChooseFolder: { chooseRootFolder(for: selectedRootIndex) }
                )
                .id(selectedRootIndex)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select a target")
                        .font(.headline)
                    Text("Choose a target on the left to edit its folder, retention, and action.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func bindingForRoot(at index: Int) -> Binding<RootRuleConfig> {
        Binding(
            get: {
                guard viewModel.config.roots.indices.contains(index) else {
                    return RootRuleConfig(
                        name: "",
                        path: "",
                        retentionDays: 30,
                        action: .trash,
                        exclusions: .default
                    )
                }
                return viewModel.config.roots[index]
            },
            set: {
                guard viewModel.config.roots.indices.contains(index) else {
                    return
                }
                viewModel.config.roots[index] = $0
            }
        )
    }

    private func addTarget() {
        viewModel.addRootTarget()
        selectedRootIndex = max(0, viewModel.config.roots.count - 1)
    }

    private func removeSelectedTarget() {
        guard let selectedRootIndex else {
            return
        }
        removeTarget(at: selectedRootIndex)
    }

    private func removeTarget(at index: Int) {
        guard viewModel.config.roots.indices.contains(index) else {
            return
        }
        if selectedRootIndex == index {
            selectedRootIndex = nil
        }
        viewModel.removeRootTarget(at: index)
        ensureSelectionIsValid(preferredIndex: index)
    }

    private func ensureSelectionIsValid(preferredIndex: Int? = nil) {
        guard !viewModel.config.roots.isEmpty else {
            selectedRootIndex = nil
            return
        }

        if let preferredIndex {
            if preferredIndex < viewModel.config.roots.count {
                selectedRootIndex = preferredIndex
            } else {
                selectedRootIndex = viewModel.config.roots.count - 1
            }
            return
        }

        if let selectedRootIndex, viewModel.config.roots.indices.contains(selectedRootIndex) {
            return
        }
        selectedRootIndex = 0
    }

    private func chooseRootFolder(for index: Int) {
        guard viewModel.config.roots.indices.contains(index) else {
            return
        }

        let trimmed = viewModel.config.roots[index].path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selectedPath = pickFolderWithFinder(
            title: "Choose Cleanup Folder",
            prompt: "Choose Folder",
            initialPath: trimmed
        ) else {
            return
        }

        guard viewModel.config.roots.indices.contains(index) else {
            return
        }
        viewModel.config.roots[index].path = selectedPath
        if viewModel.config.roots[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.config.roots[index].name = URL(fileURLWithPath: selectedPath).lastPathComponent
        }
    }

    private func chooseArchiveFolder() {
        let trimmed = viewModel.config.archive.basePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selectedPath = pickFolderWithFinder(
            title: "Choose Archive Folder",
            prompt: "Choose Folder",
            initialPath: trimmed
        ) else {
            return
        }
        viewModel.config.archive.basePath = selectedPath
    }

    private func pickFolderWithFinder(title: String, prompt: String, initialPath: String) -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = prompt
        panel.message = "Pick a folder using Finder."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = true

        let trimmed = initialPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: FluxusPaths.expandTilde(in: trimmed))
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url.path
    }
}
