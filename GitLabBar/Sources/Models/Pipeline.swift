import Foundation

/// A single GitLab CI/CD pipeline run.
struct Pipeline: Codable, Sendable, Identifiable, Hashable {
    let id: Int
    let projectId: Int?
    let iid: Int?
    let ref: String?
    let sha: String?
    let status: PipelineStatus
    let source: String?
    let webUrl: String
    let createdAt: Date?
    let updatedAt: Date?
    let user: GitLabUser?

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case iid
        case ref, sha, status, source, user
        case webUrl = "web_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Pipeline grouped with the project it belongs to, for display purposes.
struct PipelineEntry: Identifiable, Hashable, Sendable {
    let project: ProjectConfig
    let pipeline: Pipeline

    var id: String { "\(project.id)-\(pipeline.id)" }

    /// Human-readable label, e.g. `myorg/web` `feature/login #1234`.
    var displayLabel: String {
        let branch = pipeline.ref ?? "?"
        let number = pipeline.iid.map { "#\($0)" } ?? ""
        return "\(branch) \(number)".trimmingCharacters(in: .whitespaces)
    }
}
