import Foundation

/// A flattened snapshot of one pipeline at a point in time, suitable for the
/// persisted history file. Decoupled from `Pipeline` so future GitLab schema
/// tweaks don't break disk records.
struct PipelineHistoryRecord: Codable, Sendable, Identifiable, Hashable {
    let projectID: String
    let projectName: String
    let pipelineID: Int
    let iid: Int?
    let ref: String?
    let status: PipelineStatus
    let webUrl: String
    let updatedAt: Date
    let recordedAt: Date

    /// Composite ID — one record per `(project, pipeline)` pair.
    var id: String { "\(projectID)-\(pipelineID)" }

    init(entry: PipelineEntry, now: Date = Date()) {
        self.projectID   = entry.project.id
        self.projectName = entry.project.displayName
        self.pipelineID  = entry.pipeline.id
        self.iid         = entry.pipeline.iid
        self.ref         = entry.pipeline.ref
        self.status      = entry.pipeline.status
        self.webUrl      = entry.pipeline.webUrl
        self.updatedAt   = entry.pipeline.updatedAt ?? now
        self.recordedAt  = now
    }
}
