import Foundation

/// Central place for string constants so renames don't ripple through the codebase.
/// Keep this file free of feature logic.
enum AppConstants {
    /// Bundle identifier prefix, kept in sync with `project.yml`.
    static let bundleID = "com.ncthanhngo.gitlabbar"

    // MARK: - Keychain

    static let keychainService = "\(bundleID).token"
    static let keychainAccount = "gitlab-pat"

    // MARK: - UserDefaults keys

    enum DefaultsKey {
        static let gitlabBaseURL    = "gitlabBaseURL"
        static let pollIntervalSecs = "pollIntervalSecs"
        static let perPage          = "perPage"
        static let projectsJSON     = "projectsJSON"
        static let notifyOnFailed   = "notifyOnFailed"
        static let notifyOnSuccess  = "notifyOnSuccess"
        static let notificationsOn  = "notificationsOn"
    }

    // MARK: - Defaults

    enum Default {
        static let pollIntervalSecs = 30
        static let perPage          = 10
        static let minPollSeconds   = 5
        static let maxPollSeconds   = 600
        static let requestTimeout: TimeInterval = 15
        static let historyLimit     = 500
    }

    // MARK: - Storage paths

    enum Storage {
        static let appSupportDir = "GitLabBar"
        static let historyFile   = "pipeline-history.json"
    }

    // MARK: - Window IDs

    enum WindowID {
        static let history  = "history"
        static let settings = "settings"
    }

    // MARK: - Notification user-info keys

    enum NotificationInfoKey {
        static let url = "url"
    }

    // MARK: - GitLab API

    enum API {
        static let pipelinesPath    = "/api/v4/projects/%@/pipelines"
        static let projectPath      = "/api/v4/projects/%@"
        static let projectsListPath = "/api/v4/projects"
        static let tokenHeader      = "PRIVATE-TOKEN"
    }
}
