import SwiftUI

struct TargetDetailEditor: View {
    @Binding var root: RootRuleConfig
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(root.displayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button("Choose in Finder…", action: onChooseFolder)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("target-choose-folder-button")
            }

            Divider()

            fieldTitle("Name")
            TextField("Optional display name", text: $root.name)
                .textFieldStyle(.roundedBorder)
                .focusable()
                .accessibilityIdentifier("target-name-field")

            fieldTitle("Folder")
            TextField("Folder path (e.g. ~/Downloads)", text: $root.path)
                .textFieldStyle(.roundedBorder)
                .focusable()
                .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .accessibilityIdentifier("target-folder-path-field")

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldTitle("File age limit")
                    Stepper(value: $root.retentionDays, in: 0...3650) {
                        Text("\(root.retentionDays) day\(root.retentionDays == 1 ? "" : "s")")
                            .monospacedDigit()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldTitle("Action")
                    Picker("Action", selection: $root.action) {
                        ForEach(CleanupAction.allCases) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
