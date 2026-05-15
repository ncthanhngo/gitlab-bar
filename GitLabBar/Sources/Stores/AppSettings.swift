import Foundation
import Combine
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

    /// Published separately because `[ProjectConfig]` is not `AppStorage`-friendly.
    @Published var projects: [ProjectConfig] = [] {
        didSet { persistProjects() }
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
        // Load token from keychain without retriggering didSet write.
        if let saved = KeychainHelper.loadToken() {
            self._token = Published(initialValue: saved)
        }
    }

    /// Returns a configured API client, or `nil` if settings are incomplete.
    func makeClient() -> GitLabAPI? {
        let trimmed = gitlabBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme?.hasPrefix("http") == true,
              !token.isEmpty
        else { return nil }
        return GitLabAPIClient(baseURL: url, token: token)
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
}
