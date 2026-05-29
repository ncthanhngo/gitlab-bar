import SwiftUI
import AppKit

/// One job entry — status icon, stage badge, name, duration, log link.
struct JobRowView: View {
    let job: PipelineJob
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: job.status.sfSymbol)
                .foregroundStyle(job.status.tint)
                .frame(width: 12)
            stageBadge
            Text(job.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if let d = job.durationSeconds, d > 0 {
                Text(formatDuration(d))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button(action: openInBrowser) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0.35)
            .help("Open job log")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy log URL") { copyToClipboard(job.webUrl) }
            Button("Copy job name") { copyToClipboard(job.name) }
            Button("Open in browser", action: openInBrowser)
        }
    }

    private var stageBadge: some View {
        Text(job.stage)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(stageColor(job.stage).opacity(0.18))
            )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func openInBrowser() {
        guard let url = URL(string: job.webUrl) else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyToClipboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
}

/// Stable hash-derived color so each stage name maps to the same color across pipelines.
func stageColor(_ stage: String) -> Color {
    let palette: [Color] = [.blue, .purple, .teal, .indigo, .mint, .pink, .orange, .brown, .cyan]
    let h = abs(stage.hashValue)
    return palette[h % palette.count]
}
