import Foundation

/// Abstraction over GitLab's REST API so views and the monitor can depend on
/// behaviour rather than the concrete `URLSession`-backed implementation.
/// Conform a fake to `GitLabAPI` for tests.
protocol GitLabAPI: Sendable {
    func recentPipelines(projectID: String, perPage: Int) async throws -> [Pipeline]
    func projectInfo(projectID: String) async throws -> GitLabProjectInfo
}

/// Errors surfaced by any `GitLabAPI` implementation.
enum GitLabAPIError: LocalizedError {
    case invalidBaseURL
    case missingToken
    case http(status: Int, body: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:        return "GitLab base URL is invalid."
        case .missingToken:          return "Personal access token is not configured."
        case .http(let s, let b):    return "HTTP \(s): \(b.prefix(200))"
        case .transport(let e):      return "Network error: \(e.localizedDescription)"
        case .decoding(let e):       return "Decoding error: \(e.localizedDescription)"
        }
    }
}
