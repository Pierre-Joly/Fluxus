import Foundation

extension CleanupEngine {
    struct FileIdentity: Equatable {
        let device: UInt64
        let inode: UInt64
    }

    struct Candidate {
        let rootIndex: Int
        let root: RootRuleConfig
        let url: URL
        let modifiedDate: Date
        let sizeBytes: Int64
        let identity: FileIdentity
    }

    struct ScanResult {
        var candidates: [Candidate] = []
        var roots: [RootExecutionSummary] = []
        var issues: [String] = []
    }

    struct RootScanResult {
        let summary: RootExecutionSummary
        let candidates: [Candidate]
    }

    struct RunAccumulator {
        var roots: [RootExecutionSummary]
        var processedCount: Int = 0
        var trashedCount: Int = 0
        var archivedCount: Int = 0
        var skippedCount: Int = 0
        var errorCount: Int = 0
        var totalBytes: Int64 = 0
        var errors: [OperationError] = []
        var topFoldersMap: [String: (count: Int, bytes: Int64)] = [:]

        init(roots: [RootExecutionSummary]) {
            self.roots = roots
            for index in self.roots.indices {
                self.roots[index].processedCount = 0
                self.roots[index].bytes = 0
            }
        }
    }
}
