import SwiftUI
import AppKit

/// The popover content displayed when the menu bar icon is clicked.
struct MenuBarContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: PipelineMonitor

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .padding(.vertical, 8)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: monitor.overall.sfSymbol)
                .foregroundStyle(headerTint)
            Text(headerTitle).font(.headline)
            Spacer()
            if monitor.isLoading { ProgressView().controlSize(.small) }
            Button {
                Task { await monitor.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var content: some View {
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
        let projectIDs = settings.projects.map { $0.id }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(projectIDs, id: \.self) { pid in
                    if let entries = grouped[pid], !entries.isEmpty {
                        projectSection(name: entries[0].project.displayName, entries: entries)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 420)
    }

    private func projectSection(name: String, entries: [PipelineEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            ForEach(entries.prefix(5)) { entry in
                PipelineRowView(entry: entry)
            }
        }
    }

    @Environment(\.openWindow) private var openWindow

    private var footer: some View {
        HStack {
            if let err = monitor.lastError {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(err).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            } else if let when = monitor.lastRefresh {
                Text("Updated \(when, style: .relative) ago").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(" ").font(.caption2)
            }
            Spacer()
            Button("History…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: AppConstants.WindowID.history)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            Button("Settings…") { openSettings() }
                .buttonStyle(.borderless)
                .font(.caption)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
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

    private func openSettings() {
        // macOS 14+ exposes SettingsLink, but for max compatibility we use the AppKit selector.
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
