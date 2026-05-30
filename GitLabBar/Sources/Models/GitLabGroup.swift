import Foundation

/// Minimal subset of the `/groups` endpoint payload, used by the Token tab to
/// pick a group to mint an access token for.
struct GitLabGroup: Codable, Sendable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullPath: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullPath = "full_path"
    }
}
