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
            MenuBarLabelView(overall: monitor.overall, runningCount: runningCount)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(monitor)
                .frame(width: 520, height: 520)
        }

        Window("Pipeline History", id: AppConstants.WindowID.history) {
            HistoryView()
                .environmentObject(history)
        }
        .defaultSize(width: 600, height: 480)
    }

    private var runningCount: Int {
        monitor.entries
            .reduce(into: [String: Pipeline]()) { acc, entry in
                let existing = acc[entry.project.id]
                if existing == nil ||
                    (entry.pipeline.updatedAt ?? .distantPast) > (existing!.updatedAt ?? .distantPast) {
                    acc[entry.project.id] = entry.pipeline
                }
            }
            .values
            .filter { $0.status.isActive }
            .count
    }
}

/// The compact view rendered inside the menu bar slot.
struct MenuBarLabelView: View {
    let overall: OverallStatus
    let runningCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: overall.sfSymbol)
            if runningCount > 0 {
                Text("\(runningCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}
