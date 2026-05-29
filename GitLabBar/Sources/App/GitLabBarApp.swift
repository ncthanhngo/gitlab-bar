import SwiftUI

@main
struct GitLabBarApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var history: PipelineHistoryStore
    @StateObject private var monitor: PipelineMonitor
    @StateObject private var mrMonitor: MRMonitor
    private let webhook = WebhookReceiver()

    init() {
        let s = AppSettings.shared
        let h = PipelineHistoryStore()
        let m = PipelineMonitor(settings: s, history: h)
        let mr = MRMonitor(settings: s)
        _history = StateObject(wrappedValue: h)
        _monitor = StateObject(wrappedValue: m)
        _mrMonitor = StateObject(wrappedValue: mr)
        let receiver = webhook
        Task { @MainActor in
            m.start()
            mr.start()
            await NotificationService.shared.requestAuthorization()
            receiver.onEvent = { [weak m] payload in
                m?.acceptWebhookEvent(payload)
            }
            if s.webhookEnabled {
                let secret = s.ensureWebhookSecret()
                do {
                    try receiver.start(port: UInt16(s.webhookPort), secret: secret)
                } catch {
                    AppLogger.api.error("webhook listener failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(settings)
                .environmentObject(monitor)
                .environmentObject(mrMonitor)
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
