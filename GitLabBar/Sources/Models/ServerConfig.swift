import Foundation

/// A GitLab instance (URL + label). Token lives in the Keychain keyed by `id`.
/// Multiple `ServerConfig` allow watching self-hosted + gitlab.com simultaneously.
/// The legacy single-server config (`AppSettings.gitlabBaseURL`) keeps working
/// for projects that don't carry a `serverID` — `nil` means "use legacy".
struct ServerConfig: Codable, Sendable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var url: String

    init(id: UUID = UUID(), name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }

    var hostname: String {
        URL(string: url)?.host ?? url
    }
}
