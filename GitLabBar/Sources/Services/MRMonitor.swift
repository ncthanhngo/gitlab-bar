import Foundation
import Combine

/// Polls authored + review-requested MRs, exposing two published lists.
/// Polls no faster than `mrPollSeconds`; the popover refreshes on open.
@MainActor
final class MRMonitor: ObservableObject {
    @Published private(set) var mine: [MergeRequest] = []
    @Published private(set) var reviewRequests: [MergeRequest] = []
    /// Flips to true after the first fetch so the popover can tell "loading" from "empty".
    @Published private(set) var hasLoaded = false

    private var lastFetchAt: Date?

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
                let secs = max(AppConstants.Default.mrPollSeconds, self.settings.pollIntervalSecs)
                try? await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Refresh unless the last fetch is younger than `maxAge`. Called when the
    /// popover opens, since background polling is deliberately slow.
    func refreshIfStale(maxAge: TimeInterval = 10) async {
        if let at = lastFetchAt, Date().timeIntervalSince(at) < maxAge { return }
        await refresh()
    }

    func refresh() async {
        // Fan out across every configured server (legacy + multi-instance).
        var clients: [GitLabAPI] = []
        if let legacy = settings.makeClient(for: nil) { clients.append(legacy) }
        for server in settings.servers {
            if let c = settings.makeClient(for: server.id) { clients.append(c) }
        }
        guard !clients.isEmpty else {
            if !mine.isEmpty { mine = [] }
            if !reviewRequests.isEmpty { reviewRequests = [] }
            return
        }

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
        // Assign only on change so an unchanged poll doesn't re-render the scene.
        if mine != allCreated { mine = allCreated }
        let mineIDs = Set(allCreated.map(\.id))
        let reviews = allReviewer.filter { !mineIDs.contains($0.id) }
        if reviewRequests != reviews { reviewRequests = reviews }
        lastFetchAt = Date()
        if !hasLoaded { hasLoaded = true }
    }
}
