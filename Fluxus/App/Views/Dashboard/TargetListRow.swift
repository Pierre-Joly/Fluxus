import SwiftUI

struct TargetListRow: View {
    let root: RootRuleConfig

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(root.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(root.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text("\(root.retentionDays)d")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.5), in: Capsule())

                    Text(root.action.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(root.action == .trash ? .orange : .blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
