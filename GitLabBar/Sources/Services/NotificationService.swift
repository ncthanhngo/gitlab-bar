import Foundation
import AppKit
import UserNotifications

/// Wrapper around `UNUserNotificationCenter` for transition notifications.
/// The delegate handles click-to-open: tapping a banner opens the embedded URL
/// in the default browser via `NSWorkspace`.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    /// Request banner + sound authorization. Returns `true` if granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            AppLogger.ui.error("notification auth failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Post a banner. `url` is stored in `userInfo` so the delegate can open it on tap.
    func send(title: String, body: String, url: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        if let url { content.userInfo = [AppConstants.NotificationInfoKey.url: url] }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                AppLogger.ui.error("notification add failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even when GitLabBar is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Open the pipeline URL when the user clicks the banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let raw = info[AppConstants.NotificationInfoKey.url] as? String,
           let url = URL(string: raw) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }
}
