import Foundation

/// Abstraction over GitLab's REST API so views and the monitor can depend on
/// behaviour rather than the concrete `URLSession`-backed implementation.
/// Conform a fake to `GitLabAPI` for tests.
protocol GitLabAPI: Sendable {
    func recentPipelines(projectID: String, perPage: Int) async throws -> [Pipeline]
    func recentPipelines(projectID: String, ref: String?, perPage: Int) async throws -> [Pipeline]
    func projectInfo(projectID: String) async throws -> GitLabProjectInfo
    /// Projects the authenticated user is a member of, sorted by latest activity.
    func userProjects(perPage: Int) async throws -> [GitLabProjectInfo]
    /// Jobs of a given pipeline. Used for the in-popover drill-down.
    func pipelineJobs(projectID: String, pipelineID: Int) async throws -> [PipelineJob]
    /// Retry failed jobs of a pipeline.
    func retryPipeline(projectID: String, pipelineID: Int) async throws
    /// Cancel running jobs of a pipeline.
    func cancelPipeline(projectID: String, pipelineID: Int) async throws
    /// Authenticated user identity.
    func currentUser() async throws -> GitLabUser
    /// Merge requests for the authenticated user.
    func mergeRequests(scope: MRScope) async throws -> [MergeRequest]
    /// Groups the user can administer (member with at least Maintainer access),
    /// used to pick a target for the Group Access Token generator.
    func administrableGroups(perPage: Int) async throws -> [GitLabGroup]
    /// Create a new Group Access Token in `groupID` with the given scope and
    /// expiry. Requires the calling token to have `api` scope and the user to be
    /// Owner (or Maintainer, per instance config) of the group.
    func createGroupAccessToken(groupID: Int,
                                name: String,
                                scope: String,
                                accessLevel: Int,
                                expiresAt: Date) async throws -> GeneratedToken
    /// Revoke a previously created Group Access Token.
    func revokeGroupAccessToken(groupID: Int, tokenID: Int) async throws
}

extension GitLabAPI {
    /// Back-compat overload — defaults `ref` to nil.
    func recentPipelines(projectID: String, perPage: Int) async throws -> [Pipeline] {
        try await recentPipelines(projectID: projectID, ref: nil, perPage: perPage)
    }
}

enum MRScope: String, Sendable {
    case createdByMe = "created_by_me"
    case reviewer    = "reviewer"
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
