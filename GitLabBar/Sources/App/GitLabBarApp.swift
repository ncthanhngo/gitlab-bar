import SwiftUI

@main
struct GitLabBarApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var history: PipelineHistoryStore
    @StateObject private var monitor: PipelineMonitor

    init() {
        let s = AppSettings.shared
        let h = PipelineHistoryStore()
        _history = StateObject(wrappedValue: h)
        _monitor = StateObject(wrappedValue: PipelineMonitor(settings: s, history: h))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(settings)
                .environmentObject(monitor)
                .frame(width: 380)
                .onAppear {
                    monitor.start()
                    Task { await NotificationService.shared.requestAuthorization() }
                }
        } label: {
            MenuBarLabelView(state: menuBarState)
        }
        .menuBarExtraStyle(.window)

        Window("GitLabBar Settings", id: AppConstants.WindowID.settings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(monitor)
                .frame(width: 520, height: 520)
        }
        .defaultSize(width: 520, height: 520)
        .windowResizability(.contentSize)

        Window("Pipeline History", id: AppConstants.WindowID.history) {
            HistoryView()
                .environmentObject(history)
        }
        .defaultSize(width: 640, height: 480)
    }

    /// Compute the compact menu bar state from the latest pipeline of each project.
    /// `idle` means no running pipelines (regardless of last-known success/failure);
    /// `running` carries an abbreviation of the most recently active project plus
    /// the total number of projects with a running pipeline.
    private var menuBarState: MenuBarState {
        var latestByProject: [String: PipelineEntry] = [:]
        for entry in monitor.entries {
            let existing = latestByProject[entry.project.id]
            if existing == nil ||
                (entry.pipeline.updatedAt ?? .distantPast) >
                (existing!.pipeline.updatedAt ?? .distantPast) {
                latestByProject[entry.project.id] = entry
            }
        }
        let running = latestByProject.values.filter { $0.pipeline.status.isActive }
        guard !running.isEmpty else { return .idle }
        let newest = running.max {
            ($0.pipeline.updatedAt ?? .distantPast) < ($1.pipeline.updatedAt ?? .distantPast)
        }!
        return .running(
            abbreviation: MenuBarLabelView.abbreviate(newest.project.displayName),
            count: running.count
        )
    }
}
