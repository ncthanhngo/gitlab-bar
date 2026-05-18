import SwiftUI
import AppKit

/// Popover content for the click-to-copy snippet store.
/// Lives in the menu bar header so the user can copy any saved string
/// (tokens, ids, commands…) without opening Settings.
struct SnippetsMenuView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var newLabel: String = ""
    @State private var newValue: String = ""
    @State private var justCopiedID: UUID?
    @State private var revealedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Snippets")
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            if settings.snippets.isEmpty {
                Text("No snippets yet. Paste a value below to save one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            } else {
                snippetList
            }

            Divider().padding(.horizontal, 6)
            addRow
        }
        .padding(.bottom, 10)
        .frame(width: 320)
    }

    private var snippetList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(settings.snippets) { snippet in
                    snippetRow(snippet)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(maxHeight: 240)
    }

    private func snippetRow(_ snippet: SavedSnippet) -> some View {
        let isCopied = justCopiedID == snippet.id
        let isRevealed = revealedID == snippet.id
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(isRevealed ? snippet.value : String(repeating: "•", count: min(snippet.value.count, 16)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 4)
            Button {
                revealedID = isRevealed ? nil : snippet.id
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(isRevealed ? "Hide value" : "Reveal value")

            Button {
                copy(snippet)
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(isCopied ? .green : .accentColor)
            }
            .buttonStyle(.borderless)
            .help("Copy value")

            Button(role: .destructive) {
                settings.removeSnippet(id: snippet.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete snippet")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.04))
        )
        .contentShape(Rectangle())
        .onTapGesture { copy(snippet) }
    }

    private var addRow: some View {
        VStack(spacing: 6) {
            TextField("Label (optional)", text: $newLabel)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 6) {
                TextField("Paste value here…", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                Button {
                    pasteFromClipboard()
                } label: {
                    Image(systemName: "clipboard")
                }
                .buttonStyle(.borderless)
                .help("Paste from clipboard")
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    private func copy(_ snippet: SavedSnippet) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(snippet.value, forType: .string)
        justCopiedID = snippet.id
        AppLogger.ui.debug("snippet copied: \(snippet.id.uuidString, privacy: .public)")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if justCopiedID == snippet.id { justCopiedID = nil }
        }
    }

    private func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            newValue = str
        }
    }

    private func save() {
        settings.addSnippet(label: newLabel, value: newValue)
        newLabel = ""
        newValue = ""
    }
}
