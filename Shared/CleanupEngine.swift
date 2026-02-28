import Foundation

struct CleanupEngine {
    let fileManager: FileManager
    let nowProvider: () -> Date
    let logger: (String) -> Void

    init(
        fileManager: FileManager = .default,
        nowProvider: @escaping () -> Date = Date.init,
        logger: @escaping (String) -> Void = { _ in }
    ) {
        self.fileManager = fileManager
        self.nowProvider = nowProvider
        self.logger = logger
    }
}
