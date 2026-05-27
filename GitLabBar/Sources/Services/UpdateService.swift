import Foundation

/// Checks GitHub for a newer release and runs `brew upgrade gitlab-bar` in place.
/// The app is distributed via Homebrew (see Formula/gitlab-bar.rb), so we shell
/// out to `brew` rather than reimplementing a download/sign/replace flow.
struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let htmlUrl: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }

    /// "v0.5.0" → "0.5.0"
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }
}

enum UpdateError: LocalizedError {
    case network(String)
    case brewFailed(String)

    var errorDescription: String? {
        switch self {
        case .network(let m):    return "Could not contact GitHub: \(m)"
        case .brewFailed(let m): return m
        }
    }
}

enum UpdateService {
    static let owner = "ncthanhngo"
    static let repo  = "gitlab-bar"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            throw UpdateError.network("bad URL")
        }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("GitLabBar/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                throw UpdateError.network("HTTP \(http.statusCode)")
            }
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch let err as UpdateError {
            throw err
        } catch {
            throw UpdateError.network(error.localizedDescription)
        }
    }

    /// Semver-ish comparison; returns true when `latest > current`.
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let l = latest.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(l.count, c.count) {
            let lv = i < l.count ? l[i] : 0
            let cv = i < c.count ? c[i] : 0
            if lv != cv { return lv > cv }
        }
        return false
    }

    /// Run `brew update && brew upgrade gitlab-bar` via a login shell so the
    /// user's PATH (Apple Silicon vs Intel brew prefix) is respected.
    static func runBrewUpgrade() async throws -> String {
        try await Task.detached(priority: .userInitiated) { () throws -> String in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "brew update && brew upgrade gitlab-bar 2>&1"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
            } catch {
                throw UpdateError.brewFailed("Could not launch brew: \(error.localizedDescription). Install Homebrew or update manually from the Releases page.")
            }
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus != 0 {
                throw UpdateError.brewFailed(output.isEmpty ? "brew exited with code \(process.terminationStatus)" : output)
            }
            return output
        }.value
    }
}
