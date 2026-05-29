import SwiftUI
import AppKit

/// One MR row — pipeline status icon, title, branch, notes count, time.
struct MRRowView: View {
    let mr: MergeRequest
    @State private var hovering = false

    var body: some View {
        Button(action: openInBrowser) {
            HStack(spacing: 8) {
                pipelineIcon
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        if mr.draft == true {
                            Text("DRAFT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        Text(mr.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    HStack(spacing: 4) {
                        if let ref = mr.references?.full ?? mr.references?.relative {
                            Text(ref).foregroundStyle(.secondary)
                                .font(.system(size: 10, design: .monospaced))
                        } else {
                            Text("!\(mr.iid)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Text("·").foregroundStyle(.secondary)
                        Text(mr.sourceBranch)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let notes = mr.userNotesCount, notes > 0 {
                            Text("·").foregroundStyle(.secondary)
                            Label("\(notes)", systemImage: "bubble.left")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(.secondary)
                        }
                        if let updated = mr.updatedAt {
                            Text("·").foregroundStyle(.secondary)
                            Text(updated, style: .relative).foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 10))
                    .lineLimit(1)
                }
                Spacer()
                if hovering {
                    Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
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
        .contextMenu {
            Button("Copy MR URL")  { copy(mr.webUrl) }
            Button("Copy !\(mr.iid)") { copy("!\(mr.iid)") }
            Button("Open in browser", action: openInBrowser)
        }
    }

    @ViewBuilder
    private var pipelineIcon: some View {
        let status = mr.headPipeline?.status
        Image(systemName: status?.sfSymbol ?? "circle.dotted")
            .foregroundStyle(status?.tint ?? .secondary)
            .frame(width: 14)
    }

    private func copy(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private func openInBrowser() {
        guard let url = URL(string: mr.webUrl) else { return }
        NSWorkspace.shared.open(url)
    }
}
