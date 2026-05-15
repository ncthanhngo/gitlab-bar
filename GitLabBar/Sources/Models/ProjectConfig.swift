import Foundation

/// A GitLab project the user wants to monitor.
/// `id` may be a numeric project ID or a URL-encoded path (`group%2Fname`).
struct ProjectConfig: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var displayName: String

    init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = (displayName?.isEmpty == false) ? displayName! : id
    }
}

/// Minimal GitLab project info returned when fetching `/projects/:id`.
struct GitLabProjectInfo: Codable, Sendable {
    let id: Int
    let name: String
    let pathWithNamespace: String
    let webUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case pathWithNamespace = "path_with_namespace"
        case webUrl = "web_url"
    }
}
