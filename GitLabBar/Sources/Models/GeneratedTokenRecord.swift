import Foundation

/// A token minted via the Token tab, kept around so the user can copy it
/// repeatedly until it expires. Persisted (secret) in the Keychain.
///
/// `effectiveExpiry` is when the app should stop showing it: for day-based
/// tokens that's GitLab's own expiry; for the "2 hours" option it's
/// `createdAt + 2h`, at which point the janitor revokes the still-valid GitLab
/// token (`needsRevoke == true`) before dropping it.
struct GeneratedTokenRecord: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    /// Server the token lives on (`nil` = legacy single-server config).
    let serverID: UUID?
    let groupID: Int
    let groupPath: String
    /// GitLab's numeric token id, used to revoke.
    let gitlabTokenID: Int
    let token: String
    let scope: String
    let createdAt: Date
    let effectiveExpiry: Date
    /// True when the GitLab token outlives `effectiveExpiry` and the app must
    /// actively revoke it (the "2 hours" option).
    let needsRevoke: Bool

    var isExpired: Bool { Date() >= effectiveExpiry }
}
