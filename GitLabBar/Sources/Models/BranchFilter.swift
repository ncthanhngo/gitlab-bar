import Foundation

/// Per-project branch filtering rule applied after the API fetch.
/// `.single` is special: passed to the API as `?ref=` so we don't waste bandwidth.
enum BranchFilter: Sendable, Hashable, Codable {
    case all
    case protectedOnly
    case mine
    case regex(String)
    case single(String)

    var displayLabel: String {
        switch self {
        case .all:           return "All branches"
        case .protectedOnly: return "Protected only"
        case .mine:          return "My pipelines"
        case .regex(let p):  return "Regex: \(p)"
        case .single(let r): return "Ref: \(r)"
        }
    }

    /// Ref passed to the API. Only `.single` benefits from server-side filtering.
    var apiRef: String? {
        if case .single(let r) = self { return r }
        return nil
    }
}
