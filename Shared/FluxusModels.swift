import Foundation

enum CleanupAction: String, Codable, CaseIterable, Identifiable {
    case trash
    case archive

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct ArchiveConfig: Codable, Hashable {
    var basePath: String

    static var `default`: ArchiveConfig {
        ArchiveConfig(
            basePath: "~/Archive/Quarantine"
        )
    }

    var expandedBasePath: String {
        FluxusPaths.expandTilde(in: basePath)
    }
}

struct ExclusionsConfig: Codable, Hashable {
    var folderNames: [String]
    var pathContains: [String]

    static var `default`: ExclusionsConfig {
        ExclusionsConfig(folderNames: [], pathContains: [])
    }
}

struct ScheduleConfig: Codable, Hashable {
    var hour: Int
    var minute: Int

    var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }
}

struct RootRuleConfig: Codable, Hashable, Identifiable {
    var name: String
    var path: String
    var retentionDays: Int
    var action: CleanupAction
    var exclusions: ExclusionsConfig

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case retentionDays
        case action
        case exclusions
    }

    var id: String { name }

    var expandedPath: String {
        FluxusPaths.expandTilde(in: path)
    }

    init(
        name: String,
        path: String,
        retentionDays: Int,
        action: CleanupAction,
        exclusions: ExclusionsConfig = .default
    ) {
        self.name = name
        self.path = path
        self.retentionDays = retentionDays
        self.action = action
        self.exclusions = exclusions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        retentionDays = try container.decode(Int.self, forKey: .retentionDays)
        action = try container.decode(CleanupAction.self, forKey: .action)
        exclusions = try container.decodeIfPresent(ExclusionsConfig.self, forKey: .exclusions) ?? .default
    }
}

struct FluxusConfig: Codable, Hashable {
    var enabled: Bool
    var schedule: ScheduleConfig
    var roots: [RootRuleConfig]
    var archive: ArchiveConfig = .default

    enum CodingKeys: String, CodingKey {
        case enabled
        case schedule
        case roots
        case archive
    }

    var hasTargets: Bool {
        !roots.isEmpty
    }

    var canSchedule: Bool {
        enabled && hasTargets
    }

    static func `default`() -> FluxusConfig {
        FluxusConfig(
            enabled: false,
            schedule: ScheduleConfig(hour: 2, minute: 30),
            roots: [],
            archive: .default
        )
    }

    init(enabled: Bool, schedule: ScheduleConfig, roots: [RootRuleConfig], archive: ArchiveConfig = .default) {
        self.enabled = enabled
        self.schedule = schedule
        self.roots = roots
        self.archive = archive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        schedule = try container.decode(ScheduleConfig.self, forKey: .schedule)
        roots = try container.decode([RootRuleConfig].self, forKey: .roots)
        archive = try container.decodeIfPresent(ArchiveConfig.self, forKey: .archive) ?? .default
    }
}

struct CandidateRecord: Codable, Hashable, Identifiable {
    var rootName: String
    var action: CleanupAction
    var path: String
    var sizeBytes: Int64
    var modifiedAt: String
    var modifiedAtEpoch: Double

    var id: String { "\(rootName)|\(path)" }
    var actionLabel: String { action.rawValue }

    var modifiedDate: Date {
        Date(timeIntervalSince1970: modifiedAtEpoch)
    }
}

struct RootExecutionSummary: Codable, Hashable {
    var name: String
    var path: String
    var retentionDays: Int
    var action: CleanupAction
    var candidateCount: Int
    var processedCount: Int
    var bytes: Int64
    var errors: [String]
}

struct TopFolderSummary: Codable, Hashable, Identifiable {
    var folder: String
    var count: Int
    var bytes: Int64

    var id: String { folder }
}

struct OperationError: Codable, Hashable, Identifiable {
    var path: String
    var message: String

    var id: String { "\(path)|\(message)" }
}

struct ValidateOutput: Codable, Hashable {
    let command: String
    let checkedAt: String
    let valid: Bool
    let issues: [String]
}

struct SimulationOutput: Codable, Hashable {
    let command: String
    let generatedAt: String
    let candidateCount: Int
    let totalBytes: Int64
    let roots: [RootExecutionSummary]
    let candidates: [CandidateRecord]
    let issues: [String]
}

struct RunOutput: Codable, Hashable {
    let command: String
    let startedAt: String
    let finishedAt: String
    let candidateCount: Int
    let processedCount: Int
    let trashedCount: Int
    let archivedCount: Int
    let skippedCount: Int
    let errorCount: Int
    let prunedDirectoryCount: Int
    let totalBytes: Int64
    let roots: [RootExecutionSummary]
    let topFolders: [TopFolderSummary]
    let errors: [OperationError]

    enum CodingKeys: String, CodingKey {
        case command
        case startedAt
        case finishedAt
        case candidateCount
        case processedCount
        case trashedCount
        case archivedCount
        case skippedCount
        case errorCount
        case prunedDirectoryCount
        case totalBytes
        case roots
        case topFolders
        case errors
    }

    init(
        command: String,
        startedAt: String,
        finishedAt: String,
        candidateCount: Int,
        processedCount: Int,
        trashedCount: Int,
        archivedCount: Int,
        skippedCount: Int,
        errorCount: Int,
        prunedDirectoryCount: Int,
        totalBytes: Int64,
        roots: [RootExecutionSummary],
        topFolders: [TopFolderSummary],
        errors: [OperationError]
    ) {
        self.command = command
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.candidateCount = candidateCount
        self.processedCount = processedCount
        self.trashedCount = trashedCount
        self.archivedCount = archivedCount
        self.skippedCount = skippedCount
        self.errorCount = errorCount
        self.prunedDirectoryCount = prunedDirectoryCount
        self.totalBytes = totalBytes
        self.roots = roots
        self.topFolders = topFolders
        self.errors = errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decode(String.self, forKey: .command)
        startedAt = try container.decode(String.self, forKey: .startedAt)
        finishedAt = try container.decode(String.self, forKey: .finishedAt)
        candidateCount = try container.decode(Int.self, forKey: .candidateCount)
        processedCount = try container.decode(Int.self, forKey: .processedCount)
        trashedCount = try container.decode(Int.self, forKey: .trashedCount)
        archivedCount = try container.decode(Int.self, forKey: .archivedCount)
        skippedCount = try container.decode(Int.self, forKey: .skippedCount)
        errorCount = try container.decode(Int.self, forKey: .errorCount)
        prunedDirectoryCount = try container.decodeIfPresent(Int.self, forKey: .prunedDirectoryCount) ?? 0
        totalBytes = try container.decode(Int64.self, forKey: .totalBytes)
        roots = try container.decode([RootExecutionSummary].self, forKey: .roots)
        topFolders = try container.decode([TopFolderSummary].self, forKey: .topFolders)
        errors = try container.decode([OperationError].self, forKey: .errors)
    }
}

enum FluxusJSON {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        JSONDecoder()
    }

    static func isoString(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}
