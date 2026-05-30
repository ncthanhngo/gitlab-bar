import Foundation

/// Central place for string constants so renames don't ripple through the codebase.
/// Keep this file free of feature logic.
enum AppConstants {
    /// Bundle identifier prefix, kept in sync with `project.yml`.
    static let bundleID = "com.ncthanhngo.gitlabbar"

    // MARK: - Keychain

    static let keychainService = "\(bundleID).token"
    static let keychainAccount = "gitlab-pat"
    /// Account under which the list of generated (copyable) tokens is stored.
    static let keychainGeneratedTokens = "generated-tokens"

    // MARK: - UserDefaults keys

    enum DefaultsKey {
        static let gitlabBaseURL    = "gitlabBaseURL"
        static let pollIntervalSecs = "pollIntervalSecs"
        static let perPage          = "perPage"
        static let projectsJSON     = "projectsJSON"
        static let snippetsJSON     = "snippetsJSON"
        static let notifyOnFailed   = "notifyOnFailed"
        static let notifyOnSuccess  = "notifyOnSuccess"
        static let notificationsOn  = "notificationsOn"
        static let quietEnabled     = "quietHoursEnabled"
        static let quietStartMin    = "quietHoursStartMin"
        static let quietEndMin      = "quietHoursEndMin"
        static let muteUntil        = "muteUntilEpoch"
        static let webhookEnabled   = "webhookEnabled"
        static let webhookPort      = "webhookPort"
        static let webhookSecret    = "webhookSecret"
        static let serversJSON      = "serversJSON"
        static let lastTokenGroupID = "lastTokenGroupID"
        static let lastTokenExpiry  = "lastTokenExpiry"
    }

    // MARK: - Token generator

    /// Defaults for the on-demand Group Access Token generator (Token tab).
    enum TokenGenerator {
        static let scope       = "read_api"
        /// Reporter — enough for read-only API browsing, least-privilege.
        static let accessLevel = 20
        /// How often the janitor checks for tokens to revoke/purge.
        static let janitorIntervalSecs: TimeInterval = 60
        /// "Copied" feedback duration on copy buttons.
        static let copyFeedbackSecs: TimeInterval = 1.5
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
        static let pipelineJobsPath = "/api/v4/projects/%@/pipelines/%d/jobs"
        static let pipelineRetryPath  = "/api/v4/projects/%@/pipelines/%d/retry"
        static let pipelineCancelPath = "/api/v4/projects/%@/pipelines/%d/cancel"
        static let projectPath      = "/api/v4/projects/%@"
        static let projectsListPath = "/api/v4/projects"
        static let userPath         = "/api/v4/user"
        static let mergeRequestsPath = "/api/v4/merge_requests"
        static let groupsPath       = "/api/v4/groups"
        static let groupAccessTokensPath = "/api/v4/groups/%@/access_tokens"
        static let groupAccessTokenPath  = "/api/v4/groups/%@/access_tokens/%d"
        static let tokenHeader      = "PRIVATE-TOKEN"
    }

    // MARK: - Webhook receiver

    enum Webhook {
        static let defaultPort: UInt16 = 8765
        static let tokenHeader = "X-Gitlab-Token"
    }
}
