import Foundation

/// A GitLab project the user wants to monitor.
/// `id` may be a numeric project ID or a URL-encoded path (`group%2Fname`).
/// `serverID == nil` means "legacy single-server" (AppSettings.gitlabBaseURL).
struct ProjectConfig: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var filter: BranchFilter
    var serverID: UUID?

    init(id: String, displayName: String? = nil, filter: BranchFilter = .all, serverID: UUID? = nil) {
        self.id = id
        self.displayName = (displayName?.isEmpty == false) ? displayName! : id
        self.filter = filter
        self.serverID = serverID
    }

    enum CodingKeys: String, CodingKey { case id, displayName, filter, serverID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.filter = (try? c.decode(BranchFilter.self, forKey: .filter)) ?? .all
        self.serverID = try? c.decode(UUID.self, forKey: .serverID)
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
