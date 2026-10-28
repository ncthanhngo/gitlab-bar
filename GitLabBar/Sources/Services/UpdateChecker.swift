import Foundation
import AppKit

/// Shared update state for the popover: polls GitHub at most every few hours
/// and upgrades in place (brew, or signed source build for /Applications),
/// then relaunches the app.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var latestRelease: GitHubRelease?
    @Published private(set) var isInstalling = false
    @Published private(set) var lastError: String?

    private var lastCheck: Date?
    private static let checkInterval: TimeInterval = 6 * 60 * 60

    var availableVersion: String? {
        guard let latest = latestRelease,
              UpdateService.isNewer(latest.version, than: UpdateService.currentVersion) else { return nil }
        return latest.version
    }

    func checkIfStale() async {
        if let lastCheck, Date().timeIntervalSince(lastCheck) < Self.checkInterval { return }
        do {
            try await check()
        } catch {
            AppLogger.api.error("update check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func check() async throws {
        lastCheck = Date()
        latestRelease = try await UpdateService.fetchLatestRelease()
    }

    func install() {
        guard !isInstalling, let release = latestRelease else { return }
        let location = UpdateService.installLocation
        if case .other = location {
            NSWorkspace.shared.open(UpdateService.releasesURL)
            return
        }
        isInstalling = true
        lastError = nil
        Task {
            defer { isInstalling = false }
            do {
                if case .brew = location {
                    _ = try await UpdateService.runBrewUpgrade()
                    Self.relaunch()
                } else {
                    try await UpdateService.runSourceInstall(tag: release.tagName)
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    /// Spawn a detached shell that waits for us to quit, then opens the
    /// freshly upgraded bundle via brew's stable `opt` symlink.
    private static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "sleep 2; open \"$(brew --prefix gitlab-bar)/GitLabBar.app\""]
        do {
            try process.run()
        } catch {
            AppLogger.api.error("relaunch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NSApp.terminate(nil)
    }
}
