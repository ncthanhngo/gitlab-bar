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

/// Where the running app bundle lives — picks update strategy.
enum InstallLocation: Sendable {
    case brew        // /opt/homebrew/Cellar/... or /usr/local/Cellar/...
    case applications // /Applications/GitLabBar.app
    case other(URL)

    var label: String {
        switch self {
        case .brew: return "Homebrew"
        case .applications: return "/Applications"
        case .other: return "Custom location"
        }
    }
}

enum UpdateService {
    static let owner = "ncthanhngo"
    static let repo  = "gitlab-bar"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var installLocation: InstallLocation {
        let bundle = Bundle.main.bundleURL
        let path = bundle.path
        if path.contains("/Cellar/gitlab-bar/") || path.contains("/opt/homebrew/") || path.contains("/usr/local/Cellar/") {
            return .brew
        }
        if path.hasPrefix("/Applications/") {
            return .applications
        }
        return .other(bundle)
    }

    /// Release page on GitHub — the manual update fallback when brew isn't available.
    static var releasesURL: URL {
        URL(string: "https://github.com/\(owner)/\(repo)/releases/latest")!
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

    /// For signed /Applications installs: build the release tarball with its own
    /// `scripts/install-signed.sh`, which quits this app, swaps the bundle and
    /// relaunches it. Output goes to a log file, not a pipe, because the script
    /// outlives us and would die of SIGPIPE writing to a closed pipe.
    static func runSourceInstall(tag: String) async throws {
        let log = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/GitLabBar-update.log")
        let tarball = "https://github.com/\(owner)/\(repo)/archive/refs/tags/\(tag).tar.gz"
        let script = """
            set -e
            src="$(mktemp -d)"
            curl -fsSL '\(tarball)' | tar -xz -C "$src" --strip-components=1
            bash "$src/scripts/install-signed.sh"
            """
        try await Task.detached(priority: .userInitiated) { () throws -> Void in
            FileManager.default.createFile(atPath: log.path, contents: nil)
            let handle = try FileHandle(forWritingTo: log)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", script]
            process.standardOutput = handle
            process.standardError = handle
            try process.run()
            process.waitUntilExit()
            // Reaching here means the script failed before it could quit us.
            let output = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            let tail = output.split(separator: "\n").suffix(3).joined(separator: "\n")
            throw UpdateError.brewFailed(tail.isEmpty ? "Update exited with code \(process.terminationStatus)" : tail)
        }.value
    }
}
