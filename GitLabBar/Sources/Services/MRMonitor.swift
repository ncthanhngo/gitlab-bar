import Foundation
import Combine

/// Polls authored + review-requested MRs on the same cadence as the
/// pipeline monitor, exposing two published lists.
@MainActor
final class MRMonitor: ObservableObject {
    @Published private(set) var mine: [MergeRequest] = []
    @Published private(set) var reviewRequests: [MergeRequest] = []
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastRefresh: Date?

    private let settings: AppSettings
    private var pollTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                let secs = max(AppConstants.Default.minPollSeconds, self.settings.pollIntervalSecs)
                try? await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        // Fan out across every configured server (legacy + multi-instance).
        var clients: [GitLabAPI] = []
        if let legacy = settings.makeClient(for: nil) { clients.append(legacy) }
        for server in settings.servers {
            if let c = settings.makeClient(for: server.id) { clients.append(c) }
        }
        guard !clients.isEmpty else {
            mine = []
            reviewRequests = []
            return
        }
        isLoading = true
        defer { isLoading = false }

        var allCreated: [MergeRequest] = []
        var allReviewer: [MergeRequest] = []
        await withTaskGroup(of: (created: [MergeRequest], reviewer: [MergeRequest]).self) { group in
            for client in clients {
                group.addTask {
                    let c = (try? await client.mergeRequests(scope: .createdByMe)) ?? []
                    let r = (try? await client.mergeRequests(scope: .reviewer)) ?? []
                    return (c, r)
                }
            }
            for await pair in group {
                allCreated.append(contentsOf: pair.created)
                allReviewer.append(contentsOf: pair.reviewer)
            }
        }
        mine = allCreated
        let mineIDs = Set(allCreated.map(\.id))
        reviewRequests = allReviewer.filter { !mineIDs.contains($0.id) }
        lastRefresh = Date()
    }
}
