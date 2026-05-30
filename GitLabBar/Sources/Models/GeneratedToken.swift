import Foundation

/// Response of `POST /groups/:id/access_tokens` (and similar token-creation
/// endpoints). `token` is only ever returned once, at creation time.
///
/// `expires_at` arrives as a date-only string (`"2026-05-31"`), so it is kept
/// as a `String` to avoid the shared decoder's datetime-only date strategy.
struct GeneratedToken: Decodable, Sendable {
    /// GitLab's numeric token id — needed to revoke the token later.
    let id: Int
    let token: String
    let name: String?
    /// `"YYYY-MM-DD"`.
    let expiresAt: String?
    let scopes: [String]
    let accessLevel: Int?

    enum CodingKeys: String, CodingKey {
        case id, token, name, scopes
        case expiresAt = "expires_at"
        case accessLevel = "access_level"
    }
}
