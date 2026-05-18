import Foundation

/// A user-managed text snippet (e.g. a token, command, or secret label)
/// shown in the menu bar popover for one-click copy.
/// Persisted in `UserDefaults` because users explicitly opted to expose these
/// for clipboard access — true credentials still belong in the Keychain.
struct SavedSnippet: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var value: String

    init(id: UUID = UUID(), label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }

    /// Best-effort display title — falls back to a masked preview of the value
    /// when the user did not supply a label.
    var displayTitle: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let preview = value.prefix(6)
        return preview.isEmpty ? "Untitled" : "\(preview)…"
    }
}
