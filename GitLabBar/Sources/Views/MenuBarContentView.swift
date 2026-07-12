import SwiftUI
import AppKit

/// The popover content displayed when the menu bar icon is clicked.
struct MenuBarContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: PipelineMonitor
    @EnvironmentObject private var mrMonitor: MRMonitor
    @State private var showSnippets = false
    @State private var tab: PopoverTab = .pipelines

    enum PopoverTab: String, CaseIterable, Identifiable {
        case pipelines = "Pipelines"
        case mrs = "MRs"
        case token = "Token"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabSwitcher
            Divider()
            content
            Divider()
            footer
        }
        .padding(.vertical, 8)
        .onAppear { monitor.acknowledgeFailures() }
        // MenuBarExtra(.window) caches the view across opens, so `.onAppear`
        // only fires the first time. Listen for the popover window becoming
        // key as a robust "user just opened the popover" signal.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            monitor.acknowledgeFailures()
        }
    }

    private var tabSwitcher: some View {
        Picker("", selection: $tab) {
            ForEach(PopoverTab.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: monitor.overall.sfSymbol)
                .foregroundStyle(headerTint)
            Text(headerTitle).font(.headline)
            if settings.muteUntil != nil {
                Label("Muted", systemImage: "bell.slash.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .labelStyle(.titleAndIcon)
            }
            Spacer()
            if monitor.isLoading { ProgressView().controlSize(.small) }
            Button {
                showSnippets.toggle()
            } label: {
                Image(systemName: "key.fill")
            }
            .buttonStyle(.borderless)
            .help("Snippets")
            .popover(isPresented: $showSnippets, arrowEdge: .top) {
                SnippetsMenuView()
                    .environmentObject(settings)
            }
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: AppConstants.WindowID.settings)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .pipelines: pipelinesContent
        case .mrs:
            MRListView()
                .environmentObject(mrMonitor)
                .environmentObject(settings)
        case .token:
            TokenGeneratorView()
                .environmentObject(settings)
                .frame(maxHeight: 460)
        }
    }

    @ViewBuilder
    private var pipelinesContent: some View {
        if settings.makeClient() == nil {
            emptyState(
                icon: "gear",
                title: "Not configured",
                detail: "Open Settings to enter the GitLab URL and a Personal Access Token."
            )
        } else if settings.projects.isEmpty {
            emptyState(
                icon: "folder.badge.plus",
                title: "No projects",
                detail: "Add a project ID or path in Settings."
            )
        } else if monitor.entries.isEmpty && monitor.lastRefresh == nil {
            emptyState(icon: "hourglass", title: "Loading…", detail: nil)
        } else {
            pipelineList
        }
    }

    private var pipelineList: some View {
        let grouped = Dictionary(grouping: monitor.entries, by: { $0.project.id })
        // Pre-compute summaries and sort projects: running first, then failed, then green/idle.
        let projects: [ProjectSection] = settings.projects.compactMap { config in
            guard let entries = grouped[config.id], !entries.isEmpty else { return nil }
            let summary = ProjectSummary.from(entries: entries)
            return ProjectSection(
                id: config.id,
                name: entries[0].project.displayName,
                entries: entries,
                summary: summary
            )
        }
        .sorted { lhs, rhs in
            if lhs.summary.priority != rhs.summary.priority {
                return lhs.summary.priority < rhs.summary.priority
            }
            return lhs.name.lowercased() < rhs.name.lowercased()
        }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(projects) { section in
                    projectSectionView(section)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(minHeight: 480, maxHeight: 640)
    }

    private func projectSectionView(_ section: ProjectSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: section.summary.icon)
                    .foregroundStyle(section.summary.tint)
                    .imageScale(.small)
                    .frame(width: 12)
                Text(section.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if let label = section.summary.countLabel {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(section.summary.tint)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(section.summary.tint.opacity(section.summary.priority == 0 ? 0.12 : 0.0))
            )
            ForEach(section.entries.prefix(5)) { entry in
                PipelineRowView(entry: entry)
            }
        }
    }

    @Environment(\.openWindow) private var openWindow

    private var footer: some View {
        HStack(spacing: 10) {
            statusLine
            Spacer()
            Button {
                Task { await monitor.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(monitor.isLoading)
            .help("Refresh now")

            Divider().frame(height: 12)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: AppConstants.WindowID.history)
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .font(.caption)

            Divider().frame(height: 12)

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let err = monitor.lastError {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(err).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            .font(.caption2)
        } else if let when = monitor.lastRefresh {
            Text("Updated \(when, style: .relative) ago")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var headerTitle: String {
        switch monitor.overall {
        case .idle:      return "GitLab Pipelines"
        case .running:   return "Pipelines running"
        case .allGreen:  return "All green"
        case .anyFailed: return "Pipeline failed"
        case .unknown:   return "GitLab Pipelines"
        }
    }

    private var headerTint: Color {
        switch monitor.overall {
        case .running:   return .orange
        case .allGreen:  return .green
        case .anyFailed: return .red
        default:         return .secondary
        }
    }

    private func emptyState(icon: String, title: String, detail: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
            Text(title).font(.subheadline)
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

}
