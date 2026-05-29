import Foundation

/// Subset of GitLab's `object_kind=pipeline` webhook payload that we care about.
/// Reference: https://docs.gitlab.com/ee/user/project/integrations/webhook_events.html#pipeline-events
struct PipelineWebhookPayload: Decodable, Sendable {
    let objectKind: String
    let objectAttributes: Attributes
    let project: Project
    let commit: Commit?

    enum CodingKeys: String, CodingKey {
        case objectKind        = "object_kind"
        case objectAttributes  = "object_attributes"
        case project, commit
    }

    struct Attributes: Decodable, Sendable {
        let id: Int
        let iid: Int?
        let ref: String?
        let sha: String?
        let status: String
        let source: String?
        let url: String?
        let createdAt: String?
        let finishedAt: String?

        enum CodingKeys: String, CodingKey {
            case id, iid, ref, sha, status, source, url
            case createdAt   = "created_at"
            case finishedAt  = "finished_at"
        }
    }

    struct Project: Decodable, Sendable {
        let id: Int
        let pathWithNamespace: String?
        let webUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case pathWithNamespace = "path_with_namespace"
            case webUrl = "web_url"
        }
    }

    struct Commit: Decodable, Sendable {
        let id: String?
    }
}
