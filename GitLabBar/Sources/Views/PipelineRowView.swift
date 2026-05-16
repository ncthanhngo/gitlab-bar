import SwiftUI
import AppKit

/// A single pipeline row: status icon + branch + metadata.
/// Click row → copy pipeline name to clipboard. Arrow button → open in browser.
struct PipelineRowView: View {
    let entry: PipelineEntry

    @State private var hovering = false
    @State private var showCopied = false

    var body: some View {
        Button(action: copyName) {
            HStack(spacing: 8) {
                statusIcon

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.displayLabel)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 4) {
                        Text(entry.pipeline.status.displayName)
                            .foregroundStyle(entry.pipeline.status.tint)
                        if let sha = shortSHA {
                            Text("·").foregroundStyle(.secondary)
                            Text(sha)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        if let source = entry.pipeline.source, !source.isEmpty {
                            Text("·").foregroundStyle(.secondary)
                            Text(source).foregroundStyle(.secondary)
                        }
                        if let duration = durationText {
                            Text("·").foregroundStyle(.secondary)
                            Text(duration).foregroundStyle(.secondary)
                        }
                        if let updated = entry.pipeline.updatedAt {
                            Text("·").foregroundStyle(.secondary)
                            Text(updated, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                Spacer()
                if showCopied {
                    Text("Copied")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                } else {
                    Button(action: openInBrowser) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(hovering ? 1 : 0)
                    .help("Open in browser")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.gray.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(shortSHA.map { "Click to copy commit: \($0)" } ?? "No commit SHA")
    }

    /// Status icon — uses `symbolEffect(.pulse)` when running on macOS 14+.
    @ViewBuilder
    private var statusIcon: some View {
        let base = Image(systemName: entry.pipeline.status.sfSymbol)
            .foregroundStyle(entry.pipeline.status.tint)
            .frame(width: 14)
        if #available(macOS 14, *) {
            base.symbolEffect(.pulse, options: .repeating, isActive: entry.pipeline.status.isActive)
        } else {
            base
        }
    }

    private var shortSHA: String? {
        guard let sha = entry.pipeline.sha, sha.count >= 7 else { return nil }
        return String(sha.prefix(7))
    }

    private var durationText: String? {
        guard let start = entry.pipeline.createdAt else { return nil }
        let end = entry.pipeline.status.isActive ? Date() : (entry.pipeline.updatedAt ?? Date())
        let seconds = Int(end.timeIntervalSince(start))
        guard seconds > 0 else { return nil }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func copyName() {
        guard let sha = shortSHA else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(sha, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) { showCopied = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.2)) { showCopied = false }
        }
    }

    private func openInBrowser() {
        guard let url = URL(string: entry.pipeline.webUrl) else { return }
        NSWorkspace.shared.open(url)
    }
}
