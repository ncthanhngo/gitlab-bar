import Foundation
import Combine

/// Persistent, capped, in-memory mirror of pipeline records.
/// File: `~/Library/Application Support/GitLabBar/pipeline-history.json`.
@MainActor
final class PipelineHistoryStore: ObservableObject {
    @Published private(set) var records: [PipelineHistoryRecord] = []

    private let fileURL: URL
    private let limit: Int

    init(limit: Int = AppConstants.Default.historyLimit) {
        self.limit = limit
        self.fileURL = Self.resolveFileURL()
        load()
    }

    // MARK: - Public

    /// Insert-or-replace a record by composite ID, keep newest first, enforce cap.
    func record(_ entry: PipelineEntry) {
        let record = PipelineHistoryRecord(entry: entry)
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            records.insert(record, at: 0)
        }
        records.sort { $0.updatedAt > $1.updatedAt }
        if records.count > limit {
            records.removeLast(records.count - limit)
        }
        save()
    }

    /// Drop every persisted record.
    func clear() {
        records.removeAll()
        save()
    }

    /// Records grouped by project ID in display order (newest first within each).
    func grouped() -> [(projectID: String, projectName: String, records: [PipelineHistoryRecord])] {
        let grouped = Dictionary(grouping: records, by: { $0.projectID })
        return grouped.map { (key, value) in
            let name = value.first?.projectName ?? key
            return (key, name, value.sorted { $0.updatedAt > $1.updatedAt })
        }
        .sorted { $0.projectName.lowercased() < $1.projectName.lowercased() }
    }

    // MARK: - File I/O

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try Self.decoder.decode([PipelineHistoryRecord].self, from: data)
            self.records = decoded
        } catch {
            AppLogger.settings.error("history load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            let data = try Self.encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            AppLogger.settings.error("history save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private static func resolveFileURL() -> URL {
        let fm = FileManager.default
        let baseDir: URL
        do {
            baseDir = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            AppLogger.settings.error("appSupport resolve failed: \(error.localizedDescription, privacy: .public)")
            return fm.temporaryDirectory.appendingPathComponent(AppConstants.Storage.historyFile)
        }
        let appDir = baseDir.appendingPathComponent(AppConstants.Storage.appSupportDir, isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(AppConstants.Storage.historyFile)
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }()
}
