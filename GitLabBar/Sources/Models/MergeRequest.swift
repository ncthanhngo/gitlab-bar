import Foundation

/// Minimal subset of GitLab's MR payload needed for the popover view.
/// Reference: https://docs.gitlab.com/ee/api/merge_requests.html
struct MergeRequest: Codable, Sendable, Identifiable, Hashable {
    let id: Int
    let iid: Int
    let projectId: Int
    let title: String
    let state: String
    let sourceBranch: String
    let targetBranch: String
    let webUrl: String
    let userNotesCount: Int?
    let draft: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    let author: GitLabUser?
    let references: References?
    let headPipeline: Pipeline?

    struct References: Codable, Sendable, Hashable {
        let full: String?
        let relative: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, iid, title, state, draft, author, references
        case projectId       = "project_id"
        case sourceBranch    = "source_branch"
        case targetBranch    = "target_branch"
        case webUrl          = "web_url"
        case userNotesCount  = "user_notes_count"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        case headPipeline    = "head_pipeline"
    }
}
