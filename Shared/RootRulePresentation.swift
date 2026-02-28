import Foundation

extension RootRuleConfig {
    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPath.isEmpty {
            let lastComponent = URL(fileURLWithPath: FluxusPaths.expandTilde(in: trimmedPath)).lastPathComponent
            if !lastComponent.isEmpty && lastComponent != "/" {
                return lastComponent
            }
            return trimmedPath
        }

        return "Untitled Target"
    }

    var displayPath: String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPath.isEmpty ? "Folder path not set" : trimmedPath
    }
}
