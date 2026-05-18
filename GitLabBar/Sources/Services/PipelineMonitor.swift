import Foundation
import Combine

/// Aggregated status used by the menu bar icon.
enum OverallStatus: Sendable, Equatable {
    case idle           // no data yet / not configured
    case running        // at least one pipeline in active state
    case allGreen       // all latest pipelines succeeded
    case anyFailed      // any latest pipeline failed
    case unknown        // mix of non-active, non-success, non-failed

    var sfSymbol: String {
        switch self {
        case .idle:      return "circle.dotted"
        case .running:   return "arrow.triangle.2.circlepath"
        case .allGreen:  return "checkmark.circle.fill"
        case .anyFailed: return "xmark.octagon.fill"
        case .unknown:   return "questionmark.circle"
        }
    }
}

/// Polling state machine. Holds the latest pipelines and re-fetches on a timer.
@MainActor
final class PipelineMonitor: ObservableObject {
    @Published private(set) var entries: [PipelineEntry] = []
    @Published private(set) var overall: OverallStatus = .idle
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false
    /// True while there is at least one failed pipeline the user hasn't seen yet.
    /// Cleared by `acknowledgeFailures()` (invoked when the popover opens).
    @Published private(set) var hasUnacknowledgedFailure: Bool = false

    private let settings: AppSettings
    private let history: PipelineHistoryStore
    private let notifications: NotificationService
    private var pollTask: Task<Void, Never>?

    /// Last seen status of each `(projectID, pipelineID)` for transition detection.
    private var previousStatuses: [String: PipelineStatus] = [:]
    /// Failed pipelines the user has already viewed — never re-flag these.
    private var acknowledgedFailedKeys: Set<String> = []

    init(settings: AppSettings,
         history: PipelineHistoryStore,
         notifications: NotificationService = .shared) {
        self.settings = settings
        self.history = history
        self.notifications = notifications
    }

    /// Kick off the polling loop. Safe to call multiple times.
    func start() {
        pollTask?.cancel()
        AppLogger.monitor.debug("monitor starting")
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

    /// Manually trigger a refresh.
    func refresh() async {
        guard let client = settings.makeClient() else {
            self.lastError = "Missing configuration (GitLab URL or token)"
            self.overall = .idle
            return
        }
        let projects = settings.projects
        guard !projects.isEmpty else {
            self.entries = []
            self.overall = .idle
            self.lastError = nil
            return
        }
        self.isLoading = true
        defer { self.isLoading = false }

        let perPage = settings.perPage
        // Fetch all projects in parallel
        var collected: [PipelineEntry] = []
        var firstError: String?
        await withTaskGroup(of: (ProjectConfig, Result<[Pipeline], Error>).self) { group in
            for project in projects {
                group.addTask {
                    do {
                        let pipes = try await client.recentPipelines(projectID: project.id, perPage: perPage)
                        return (project, .success(pipes))
                    } catch {
                        return (project, .failure(error))
                    }
                }
            }
            for await (project, result) in group {
                switch result {
                case .success(let pipes):
                    for p in pipes {
                        collected.append(PipelineEntry(project: project, pipeline: p))
                    }
                case .failure(let err):
                    if firstError == nil {
                        firstError = "\(project.displayName): \(err.localizedDescription)"
                    }
                }
            }
        }
        // Sort newest first
        collected.sort { (lhs, rhs) in
            (lhs.pipeline.updatedAt ?? .distantPast) > (rhs.pipeline.updatedAt ?? .distantPast)
        }
        // Detect transitions before overwriting state, then archive every entry.
        emitTransitions(for: collected)
        for entry in collected { history.record(entry) }

        self.entries = collected
        self.lastError = firstError
        self.lastRefresh = Date()
        self.overall = Self.aggregate(entries: collected)
        self.refreshUnacknowledgedFailure(for: collected)
    }

    /// Mark every currently-failed pipeline as seen. Called when the user opens
    /// the menu bar popover — that's the signal we have their attention.
    func acknowledgeFailures() {
        let currentFailed = Self.failedKeys(in: entries)
        guard !currentFailed.isEmpty || hasUnacknowledgedFailure else { return }
        acknowledgedFailedKeys.formUnion(currentFailed)
        hasUnacknowledgedFailure = false
    }

    /// Recompute `hasUnacknowledgedFailure` against the latest entries. A failed
    /// pipeline that's no longer in the list (rerun, GC'd) drops from the
    /// acknowledged set too, so a future re-failure flags red again.
    private func refreshUnacknowledgedFailure(for entries: [PipelineEntry]) {
        let currentFailed = Self.failedKeys(in: entries)
        acknowledgedFailedKeys.formIntersection(currentFailed)
        hasUnacknowledgedFailure = !currentFailed.isSubset(of: acknowledgedFailedKeys)
    }

    private static func failedKeys(in entries: [PipelineEntry]) -> Set<String> {
        var out: Set<String> = []
        for entry in entries where entry.pipeline.status == .failed {
            out.insert("\(entry.project.id)-\(entry.pipeline.id)")
        }
        return out
    }

    /// Compare current entries against `previousStatuses` and post notifications
    /// for pipelines that just moved out of an active state. Updates the cache.
    private func emitTransitions(for entries: [PipelineEntry]) {
        for entry in entries {
            let key = "\(entry.project.id)-\(entry.pipeline.id)"
            let previous = previousStatuses[key]
            let current = entry.pipeline.status
            previousStatuses[key] = current

            guard let previous, previous.isActive, !current.isActive else { continue }
            guard settings.notificationsEnabled else { continue }

            switch current {
            case .failed where settings.notifyOnFailed:
                notifications.send(
                    title: "\(entry.project.displayName) — failed",
                    body: "\(entry.displayLabel) failed",
                    url: entry.pipeline.webUrl
                )
            case .success where settings.notifyOnSuccess:
                notifications.send(
                    title: "\(entry.project.displayName) — passed",
                    body: "\(entry.displayLabel) succeeded",
                    url: entry.pipeline.webUrl
                )
            default:
                break
            }
        }
    }

    /// Compute the icon state from the latest pipeline of each project.
    static func aggregate(entries: [PipelineEntry]) -> OverallStatus {
        if entries.isEmpty { return .idle }
        // Take the most recent pipeline per project
        var latestByProject: [String: Pipeline] = [:]
        for entry in entries {
            let existing = latestByProject[entry.project.id]
            if existing == nil ||
                (entry.pipeline.updatedAt ?? .distantPast) > (existing!.updatedAt ?? .distantPast) {
                latestByProject[entry.project.id] = entry.pipeline
            }
        }
        let latest = Array(latestByProject.values)
        if latest.contains(where: { $0.status.isActive }) { return .running }
        if latest.contains(where: { $0.status == .failed }) { return .anyFailed }
        if latest.allSatisfy({ $0.status == .success }) { return .allGreen }
        return .unknown
    }
}
