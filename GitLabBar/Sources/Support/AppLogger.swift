import Foundation
import os

/// Shared `os.Logger` instances grouped by concern.
/// Never log access tokens or full HTTP bodies — truncate to 200 characters.
enum AppLogger {
    private static let subsystem = AppConstants.bundleID

    static let api      = Logger(subsystem: subsystem, category: "api")
    static let monitor  = Logger(subsystem: subsystem, category: "monitor")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let ui       = Logger(subsystem: subsystem, category: "ui")
}
