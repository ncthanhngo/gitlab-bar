import Foundation

/// Append-only NDJSON event log so external tools (Claude Code hooks, CI dashboards,
/// shell scripts) can subscribe to pipeline failures without polling GitLab.
/// Path: `~/Library/Application Support/GitLabBar/pipeline-events.ndjson`.
struct PipelineFailureEvent: Codable, Sendable {
    let timestamp: Date
    let projectID: String
    let projectPath: String      // display name, usually `group/repo`
    let pipelineID: Int
    let pipelineIID: Int?
    let ref: String?
    let sha: String?
    let webURL: String
    let source: String?
    let status: String
}

enum EventLogService {

    static var logURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent(AppConstants.Storage.appSupportDir, isDirectory: true)
        _ = try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pipeline-events.ndjson")
    }

    static func append(_ event: PipelineFailureEvent) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(event) else { return }
        var line = data
        line.append(0x0A) // newline
        let url = logURL
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
                try? handle.close()
            }
        } else {
            try? line.write(to: url, options: .atomic)
        }
        AppLogger.monitor.debug("emitted pipeline event: \(event.projectPath, privacy: .public) #\(event.pipelineID, privacy: .public)")
    }
}
