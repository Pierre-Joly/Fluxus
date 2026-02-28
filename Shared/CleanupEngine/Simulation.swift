import Foundation

extension CleanupEngine {
    func simulation(config: FluxusConfig) -> SimulationOutput {
        let now = nowProvider()
        let scan = collectCandidates(config: config, now: now)
        let records = simulationRecords(from: scan.candidates)
        let totalBytes = records.reduce(Int64(0)) { $0 + $1.sizeBytes }

        return SimulationOutput(
            command: "simulate",
            generatedAt: FluxusJSON.isoString(now),
            candidateCount: records.count,
            totalBytes: totalBytes,
            roots: scan.roots,
            candidates: records,
            issues: scan.issues
        )
    }

    private func simulationRecords(from candidates: [Candidate]) -> [CandidateRecord] {
        candidates
            .sorted { $0.url.path < $1.url.path }
            .map { candidate in
                CandidateRecord(
                    rootName: candidate.root.name,
                    action: candidate.root.action,
                    path: candidate.url.path,
                    sizeBytes: candidate.sizeBytes,
                    modifiedAt: FluxusJSON.isoString(candidate.modifiedDate),
                    modifiedAtEpoch: candidate.modifiedDate.timeIntervalSince1970
                )
            }
    }
}
