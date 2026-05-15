import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` so the rest of the app can ask
/// "is launch-at-login on?" without dealing with `SMAppService.Status` directly.
@MainActor
enum LaunchAtLoginService {
    /// `true` when macOS will start the app at the next user login.
    static var isEnabled: Bool {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Register or unregister the main app. Throws on permission/setup errors.
    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13, *) else {
            throw LaunchAtLoginError.unsupportedOS
        }
        let service = SMAppService.mainApp
        if enabled {
            try service.register()
        } else if service.status == .enabled {
            try service.unregister()
        }
    }

    enum LaunchAtLoginError: LocalizedError {
        case unsupportedOS
        var errorDescription: String? {
            switch self {
            case .unsupportedOS: return "Launch at login requires macOS 13 or newer."
            }
        }
    }
}
