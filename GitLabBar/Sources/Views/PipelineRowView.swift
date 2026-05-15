import SwiftUI
import AppKit

/// A single pipeline row: status icon + branch + relative time, opens in browser on click.
struct PipelineRowView: View {
    let entry: PipelineEntry

    @State private var hovering = false

    var body: some View {
        Button(action: openInBrowser) {
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
                        if let updated = entry.pipeline.updatedAt {
                            Text("·").foregroundStyle(.secondary)
                            Text(updated, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 10))
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .opacity(hovering ? 1 : 0)
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
        .help("Open in browser")
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

    private func openInBrowser() {
        guard let url = URL(string: entry.pipeline.webUrl) else { return }
        NSWorkspace.shared.open(url)
    }
}
