import Foundation
import Combine
import Security
import SwiftUI

/// Observable singleton storing user preferences in `UserDefaults`,
/// except for the access token which lives in the keychain.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage(AppConstants.DefaultsKey.gitlabBaseURL)    var gitlabBaseURL: String = ""
    @AppStorage(AppConstants.DefaultsKey.pollIntervalSecs) var pollIntervalSecs: Int = AppConstants.Default.pollIntervalSecs
    @AppStorage(AppConstants.DefaultsKey.perPage)          var perPage: Int = AppConstants.Default.perPage
    @AppStorage(AppConstants.DefaultsKey.notificationsOn)  var notificationsEnabled: Bool = true
    @AppStorage(AppConstants.DefaultsKey.notifyOnFailed)   var notifyOnFailed: Bool = true
    @AppStorage(AppConstants.DefaultsKey.notifyOnSuccess)  var notifyOnSuccess: Bool = false
    @AppStorage(AppConstants.DefaultsKey.quietEnabled)     var quietHoursEnabled: Bool = false
    /// Minutes since midnight, local time.
    @AppStorage(AppConstants.DefaultsKey.quietStartMin)    var quietStartMin: Int = 9 * 60
    @AppStorage(AppConstants.DefaultsKey.quietEndMin)      var quietEndMin: Int = 18 * 60
    /// `0` (or past) means "not muted". Stored as Unix epoch seconds.
    @AppStorage(AppConstants.DefaultsKey.muteUntil)        var muteUntilEpoch: Double = 0
    @AppStorage(AppConstants.DefaultsKey.webhookEnabled)   var webhookEnabled: Bool = false
    @AppStorage(AppConstants.DefaultsKey.webhookPort)      var webhookPort: Int = 8765
    @AppStorage(AppConstants.DefaultsKey.webhookSecret)    var webhookSecret: String = ""

    /// Generate (or return existing) shared secret used in `X-Gitlab-Token`.
    func ensureWebhookSecret() -> String {
        if !webhookSecret.isEmpty { return webhookSecret }
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        webhookSecret = hex
        return hex
    }

    var muteUntil: Date? {
        let now = Date().timeIntervalSince1970
        return muteUntilEpoch > now ? Date(timeIntervalSince1970: muteUntilEpoch) : nil
    }

    func muteNow(for seconds: TimeInterval) {
        muteUntilEpoch = Date().addingTimeInterval(seconds).timeIntervalSince1970
    }

    func unmute() { muteUntilEpoch = 0 }

    /// Additional GitLab servers (multi-instance). Each project's `serverID`
    /// references one of these; `nil` falls back to legacy single-server fields.
    @Published var servers: [ServerConfig] = [] {
        didSet { persistServers() }
    }

    /// Per-server PAT mirrors, persisted to Keychain on change.
    @Published var serverTokens: [UUID: String] = [:] {
        didSet { persistServerTokens(old: oldValue) }
    }

    /// Published separately because `[ProjectConfig]` is not `AppStorage`-friendly.
    @Published var projects: [ProjectConfig] = [] {
        didSet { persistProjects() }
    }

    /// User-curated snippets surfaced as click-to-copy rows in the popover header.
    @Published var snippets: [SavedSnippet] = [] {
        didSet { persistSnippets() }
    }

    /// Token mirror — UI binds to this, persistence is keychain-backed.
    @Published var token: String = "" {
        didSet {
            do {
                try KeychainHelper.saveToken(token)
            } catch {
                AppLogger.settings.error("keychain save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: AppConstants.DefaultsKey.projectsJSON),
           let decoded = try? JSONDecoder().decode([ProjectConfig].self, from: data) {
            self.projects = decoded
        }
        if let data = UserDefaults.standard.data(forKey: AppConstants.DefaultsKey.snippetsJSON),
           let decoded = try? JSONDecoder().decode([SavedSnippet].self, from: data) {
            self.snippets = decoded
        }
        if let data = UserDefaults.standard.data(forKey: AppConstants.DefaultsKey.serversJSON),
           let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            self.servers = decoded
        }
        // Load tokens from keychain without retriggering didSet writes.
        if let saved = KeychainHelper.loadToken() {
            self._token = Published(initialValue: saved)
        }
        var tokens: [UUID: String] = [:]
        for s in self.servers {
            if let t = KeychainHelper.loadToken(serverID: s.id) { tokens[s.id] = t }
        }
        self._serverTokens = Published(initialValue: tokens)
    }

    /// Returns a configured API client for the **legacy single-server** config.
    /// Used when projects don't carry a `serverID`.
    func makeClient() -> GitLabAPI? {
        makeClient(for: nil)
    }

    /// Returns a configured API client for the given server (or legacy if `nil`).
    func makeClient(for serverID: UUID?) -> GitLabAPI? {
        let baseURL: String
        let pat: String
        if let serverID, let server = servers.first(where: { $0.id == serverID }) {
            baseURL = server.url
            pat = serverTokens[serverID] ?? ""
        } else {
            baseURL = gitlabBaseURL
            pat = token
        }
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme?.hasPrefix("http") == true,
              !pat.isEmpty
        else { return nil }
        return GitLabAPIClient(baseURL: url, token: pat)
    }

    func addServer(_ server: ServerConfig, token: String) {
        servers.append(server)
        if !token.isEmpty { serverTokens[server.id] = token }
    }

    func removeServer(id: UUID) {
        servers.removeAll { $0.id == id }
        serverTokens.removeValue(forKey: id)
        KeychainHelper.deleteToken(serverID: id)
        // Re-home affected projects to legacy.
        for i in projects.indices where projects[i].serverID == id {
            projects[i].serverID = nil
        }
    }

    func addProject(_ project: ProjectConfig) {
        guard !projects.contains(where: { $0.id == project.id }) else { return }
        projects.append(project)
    }

    func removeProject(at offsets: IndexSet) {
        projects.remove(atOffsets: offsets)
    }

    private func persistProjects() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: AppConstants.DefaultsKey.projectsJSON)
    }

    private func persistServers() {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        UserDefaults.standard.set(data, forKey: AppConstants.DefaultsKey.serversJSON)
    }

    private func persistServerTokens(old: [UUID: String]) {
        for (id, newToken) in serverTokens {
            if old[id] != newToken {
                try? KeychainHelper.saveToken(newToken, serverID: id)
            }
        }
        for id in Set(old.keys).subtracting(serverTokens.keys) {
            KeychainHelper.deleteToken(serverID: id)
        }
    }

    // MARK: - Snippets

    func addSnippet(label: String, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return }
        snippets.append(SavedSnippet(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            value: trimmedValue
        ))
    }

    func removeSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
    }

    private func persistSnippets() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        UserDefaults.standard.set(data, forKey: AppConstants.DefaultsKey.snippetsJSON)
    }
}
