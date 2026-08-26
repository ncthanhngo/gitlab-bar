import SwiftUI
import AppKit

/// Standalone window listing every record persisted by `PipelineHistoryStore`,
/// grouped by project, newest first.
struct HistoryView: View {
    @EnvironmentObject private var history: PipelineHistoryStore

    @State private var search: String = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 520, minHeight: 360)
    }

    // MARK: - Sections

    private var toolbar: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
            TextField("Filter by branch, status, or project", text: $search)
                .textFieldStyle(.roundedBorder)
            Button(role: .destructive) {
                history.clear()
            } label: {
                Image(systemName: "trash")
            }
            .help("Clear all history")
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        let groups = filteredGroups()
        if groups.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.title).foregroundStyle(.secondary)
                Text("No history yet").font(.subheadline)
                Text("Pipelines will appear here after the next refresh.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(groups, id: \.projectID) { group in
                        section(name: group.projectName, records: group.records)
                    }
                }
                .padding(12)
            }
        }
    }

    private func section(name: String, records: [PipelineHistoryRecord]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.headline)
            ForEach(records) { row(record: $0) }
        }
    }

    private func row(record: PipelineHistoryRecord) -> some View {
        Button {
            if let url = URL(string: record.webUrl) { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: record.status.sfSymbol)
                    .foregroundStyle(record.status.tint)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(rowTitle(record)).font(.system(size: 12, weight: .medium))
                    HStack(spacing: 6) {
                        Text(record.status.displayName).foregroundStyle(record.status.tint)
                        Text("·").foregroundStyle(.secondary)
                        Text(record.updatedAt, style: .relative).foregroundStyle(.secondary)
                    }
                    .font(.system(size: 10))
                }
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func rowTitle(_ r: PipelineHistoryRecord) -> String {
        let branch = r.ref ?? "?"
        return "\(branch) #\(r.pipelineID)"
    }

    private func filteredGroups() -> [(projectID: String, projectName: String, records: [PipelineHistoryRecord])] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let groups = history.grouped()
        guard !trimmed.isEmpty else { return groups }
        return groups.compactMap { group in
            let filtered = group.records.filter { record in
                let bag = "\(record.projectName) \(record.ref ?? "") \(record.status.rawValue)".lowercased()
                return bag.contains(trimmed)
            }
            return filtered.isEmpty ? nil : (group.projectID, group.projectName, filtered)
        }
    }
}
