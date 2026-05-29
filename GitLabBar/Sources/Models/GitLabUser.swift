import Foundation

/// Minimal subset of `/user` endpoint payload.
struct GitLabUser: Codable, Sendable, Hashable {
    let id: Int
    let username: String
    let name: String?
}
