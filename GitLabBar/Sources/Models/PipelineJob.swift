import Foundation

/// A single CI job inside a pipeline (one stage entry).
/// Reference: https://docs.gitlab.com/ee/api/jobs.html#list-pipeline-jobs
struct PipelineJob: Codable, Sendable, Identifiable, Hashable {
    let id: Int
    let name: String
    let stage: String
    let status: PipelineStatus
    let webUrl: String
    let duration: Double?
    let allowFailure: Bool?
    let createdAt: Date?
    let startedAt: Date?
    let finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, stage, status
        case webUrl = "web_url"
        case duration
        case allowFailure = "allow_failure"
        case createdAt   = "created_at"
        case startedAt   = "started_at"
        case finishedAt  = "finished_at"
    }

    var durationSeconds: Int? {
        if let duration { return Int(duration) }
        if let started = startedAt, let finished = finishedAt {
            return Int(finished.timeIntervalSince(started))
        }
        return nil
    }
}
