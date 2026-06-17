import Foundation
import SwiftUI

/// In-memory cache of recently-fetched commit metadata so the same SHA isn't
/// re-fetched when a row is collapsed/expanded or accessed from multiple
/// places (PipelineRowView context menu + JobListView header).
@MainActor
final class CommitCache: ObservableObject {
    static let shared = CommitCache()

    @Published private(set) var commits: [String: GitLabCommit] = [:]
    private var inFlight: Set<String> = []

    private func key(projectID: String, sha: String) -> String { "\(projectID)|\(sha)" }

    func cached(projectID: String, sha: String) -> GitLabCommit? {
        commits[key(projectID: projectID, sha: sha)]
    }

    /// Fetch and cache. Idempotent — concurrent calls for the same key share work.
    func fetchIfNeeded(projectID: String, sha: String, client: GitLabAPI) async {
        let k = key(projectID: projectID, sha: sha)
        guard commits[k] == nil, !inFlight.contains(k) else { return }
        inFlight.insert(k)
        defer { inFlight.remove(k) }
        if let c = try? await client.commit(projectID: projectID, sha: sha) {
            commits[k] = c
        }
    }
}
