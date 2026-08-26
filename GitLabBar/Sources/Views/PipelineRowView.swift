import SwiftUI
import AppKit

/// A single pipeline row: status icon + branch + metadata.
/// Click row → copy full commit SHA. Hover reveals retry/cancel + open in browser.
/// Right-click for full multi-copy menu. Chevron expands inline job list.
struct PipelineRowView: View {
    let entry: PipelineEntry

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: PipelineMonitor
    @EnvironmentObject private var commitCache: CommitCache

    @State private var hovering = false
    @State private var showCopied: String?
    @State private var isExpanded = false
    @State private var isPerformingAction = false

    private var commit: GitLabCommit? {
        guard let sha = entry.pipeline.sha else { return nil }
        return commitCache.cached(projectID: entry.project.id, sha: sha)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if isExpanded {
                JobListView(entry: entry)
                    .environmentObject(settings)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var mainRow: some View {
        Button(action: { copy(.fullSHA) }) {
            HStack(spacing: 8) {
                expandChevron
                statusIcon
                rowText
                Spacer()
                trailingControls
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.gray.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(entry.pipeline.sha.map { "Click to copy commit SHA: \($0)" } ?? "No commit SHA")
        .contextMenu { copyMenu }
    }

    private var rowText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.displayLabel)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            if let title = commit?.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(spacing: 4) {
                Text(entry.pipeline.status.displayName)
                    .foregroundStyle(entry.pipeline.status.tint)
                if let sha = shortSHA {
                    Text("·").foregroundStyle(.secondary)
                    Text(sha)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let source = entry.pipeline.source, !source.isEmpty {
                    Text("·").foregroundStyle(.secondary)
                    Text(source).foregroundStyle(.secondary)
                }
                if let duration = durationText {
                    Text("·").foregroundStyle(.secondary)
                    Text(duration).foregroundStyle(.secondary)
                }
                if let updated = entry.pipeline.updatedAt {
                    Text("·").foregroundStyle(.secondary)
                    Text(updated, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 10))
            .lineLimit(1)
            .truncationMode(.tail)
        }
    }

    private var expandChevron: some View {
        Button(action: toggleExpand) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 10)
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Hide jobs" : "Show jobs")
    }

    @ViewBuilder
    private var trailingControls: some View {
        if let label = showCopied {
            Text("Copied \(label)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.green)
                .transition(.opacity)
        } else if isPerformingAction {
            ProgressView().controlSize(.small)
        } else if hovering {
            actionButtons
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 6) {
            if entry.pipeline.status == .failed {
                Button(action: retry) {
                    Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("Retry pipeline")
            } else if entry.pipeline.status.isActive {
                Button(action: cancel) {
                    Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("Cancel pipeline")
            }
            Button(action: openInBrowser) {
                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).help("Open in browser")
        }
    }

    @ViewBuilder
    private var copyMenu: some View {
        if entry.pipeline.sha != nil {
            Button("Copy full SHA")  { copy(.fullSHA) }
            Button("Copy short SHA") { copy(.shortSHA) }
            Button("Copy branch @ SHA") { copy(.branchAtSha) }
        }
        Button("Copy commit title") { copy(.commitTitle) }
        Button("Copy commit message") { copy(.commitMessage) }
        Button("Copy pipeline URL") { copy(.url) }
        if entry.pipeline.iid != nil {
            Button("Copy IID (#\(entry.pipeline.iid ?? 0))") { copy(.iid) }
        }
        Divider()
        Button("Open in browser", action: openInBrowser)
    }

    @ViewBuilder
    private var statusIcon: some View {
        let base = Image(systemName: entry.pipeline.status.sfSymbol)
            .foregroundStyle(entry.pipeline.status.tint)
            .frame(width: 14)
        base
    }

    private var shortSHA: String? {
        guard let sha = entry.pipeline.sha, sha.count >= 7 else { return nil }
        return String(sha.prefix(7))
    }

    private var durationText: String? {
        guard let start = entry.pipeline.createdAt else { return nil }
        let end = entry.pipeline.status.isActive ? Date() : (entry.pipeline.updatedAt ?? Date())
        let seconds = Int(end.timeIntervalSince(start))
        guard seconds > 0 else { return nil }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func toggleExpand() {
        withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
        monitor.acknowledgeFailures()
        if isExpanded { fetchCommitThen(nil) }
    }

    /// Fetch commit metadata (if not cached) then optionally run a follow-up.
    private func fetchCommitThen(_ followUp: (() -> Void)?) {
        guard let sha = entry.pipeline.sha,
              let client = settings.makeClient(for: entry.project.serverID) else { return }
        Task { @MainActor in
            await commitCache.fetchIfNeeded(projectID: entry.project.id, sha: sha, client: client)
            followUp?()
        }
    }

    // MARK: - Actions

    private enum CopyVariant: String {
        case fullSHA = "full SHA"
        case shortSHA = "short SHA"
        case branchAtSha = "branch@SHA"
        case commitTitle = "commit title"
        case commitMessage = "commit message"
        case url = "URL"
        case iid = "IID"
    }

    private func copy(_ variant: CopyVariant) {
        // Commit variants need a cache hit — kick the fetch and retry once it lands.
        if variant == .commitTitle || variant == .commitMessage, commit == nil {
            fetchCommitThen { self.copy(variant) }
            return
        }
        let value: String?
        switch variant {
        case .fullSHA:       value = entry.pipeline.sha
        case .shortSHA:      value = shortSHA
        case .branchAtSha:   value = entry.pipeline.ref.flatMap { ref in shortSHA.map { "\(ref) @ \($0)" } }
        case .commitTitle:   value = commit?.title
        case .commitMessage: value = commit?.message
        case .url:           value = entry.pipeline.webUrl
        case .iid:           value = entry.pipeline.iid.map { "#\($0)" }
        }
        guard let v = value, !v.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(v, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) { showCopied = variant.rawValue }
        // Clicking on a row is a strong "user saw this" signal — ack failures
        // so the menu bar icon resets even if the open-popover hook missed.
        monitor.acknowledgeFailures()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.2)) { showCopied = nil }
        }
    }

    private func retry() { performAction { client in
        try await client.retryPipeline(projectID: entry.project.id, pipelineID: entry.pipeline.id)
    } }

    private func cancel() { performAction { client in
        try await client.cancelPipeline(projectID: entry.project.id, pipelineID: entry.pipeline.id)
    } }

    private func performAction(_ op: @escaping @Sendable (GitLabAPI) async throws -> Void) {
        guard let client = settings.makeClient() else { return }
        isPerformingAction = true
        Task {
            defer { isPerformingAction = false }
            do {
                try await op(client)
                await monitor.refresh()
            } catch {
                AppLogger.api.error("pipeline action failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func openInBrowser() {
        guard let url = URL(string: entry.pipeline.webUrl) else { return }
        NSWorkspace.shared.open(url)
    }
}
