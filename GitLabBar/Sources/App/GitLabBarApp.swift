import SwiftUI

@main
struct GitLabBarApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var history: PipelineHistoryStore
    @StateObject private var monitor: PipelineMonitor

    init() {
        let s = AppSettings.shared
        let h = PipelineHistoryStore()
        let m = PipelineMonitor(settings: s, history: h)
        _history = StateObject(wrappedValue: h)
        _monitor = StateObject(wrappedValue: m)
        // Start polling at app launch so the menu bar icon turns orange as soon
        // as GitLab reports a running pipeline — without needing the user to
        // open the popover first. The hop onto MainActor matches the actor
        // isolation declared on PipelineMonitor.
        Task { @MainActor in
            m.start()
            await NotificationService.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(settings)
                .environmentObject(monitor)
                .frame(width: 380)
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

    /// Compute the compact menu bar state.
    ///
    /// `running` fires when **any** pipeline returned by GitLab is in an active
    /// state — not just the latest pipeline per project. That way the icon
    /// turns orange even when an older branch's pipeline is still grinding
    /// while a newer commit on `main` already finished.
    /// The abbreviation comes from the project whose newest active pipeline
    /// was updated most recently; the count is the number of distinct
    /// projects with at least one active pipeline.
    private var menuBarState: MenuBarState {
        let activeEntries = monitor.entries.filter { $0.pipeline.status.isActive }
        if !activeEntries.isEmpty {
            // Running spinner always wins — user can see progress in real time.
            let newest = activeEntries.max {
                ($0.pipeline.updatedAt ?? .distantPast) < ($1.pipeline.updatedAt ?? .distantPast)
            }!
            let busyProjectCount = Set(activeEntries.map(\.project.id)).count
            return .running(
                abbreviation: MenuBarLabelView.abbreviate(newest.project.displayName),
                count: busyProjectCount
            )
        }
        if monitor.hasUnacknowledgedFailure {
            // Count distinct projects with an unseen failed pipeline.
            let failedProjectCount = Set(
                monitor.entries
                    .filter { $0.pipeline.status == .failed }
                    .map(\.project.id)
            ).count
            return .failed(count: failedProjectCount)
        }
        return .idle
    }
}
