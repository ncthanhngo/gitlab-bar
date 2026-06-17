import Foundation

/// Subset of `/projects/:id/repository/commits/:sha` payload.
struct GitLabCommit: Codable, Sendable, Hashable {
    let id: String       // full SHA
    let shortId: String
    let title: String
    let message: String
    let authorName: String?
    let authorEmail: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, message
        case shortId     = "short_id"
        case authorName  = "author_name"
        case authorEmail = "author_email"
        case createdAt   = "created_at"
    }
}
