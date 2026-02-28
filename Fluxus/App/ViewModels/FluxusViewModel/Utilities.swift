import Foundation

extension FluxusViewModel {
    func applySortOrder() {
        simulationCandidates.sort(using: sortOrder)
    }

    func formatBytes(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }

    func clearStatus() {
        statusMessage = ""
        statusIsError = false
    }
}
