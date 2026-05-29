import SwiftUI

/// Sheet to pick a `BranchFilter` for a single project.
struct BranchFilterSheet: View {
    let projectName: String
    @Binding var filter: BranchFilter
    var onDone: () -> Void

    @State private var mode: Mode = .all
    @State private var pattern: String = ""

    enum Mode: String, CaseIterable, Identifiable {
        case all, protectedOnly, mine, regex, single
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:           return "All branches"
            case .protectedOnly: return "Protected only (main/master/develop/release/*)"
            case .mine:          return "Only my pipelines"
            case .regex:         return "Regex pattern"
            case .single:        return "Single ref"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter for \(projectName)").font(.headline)
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.radioGroup)

            if mode == .regex {
                TextField("e.g. ^release/", text: $pattern)
                    .textFieldStyle(.roundedBorder)
                Text("Standard NSRegularExpression syntax. Tested against pipeline `ref`.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if mode == .single {
                TextField("Branch name, e.g. main", text: $pattern)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onDone)
                Button("Apply") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear { hydrate() }
    }

    private var isValid: Bool {
        switch mode {
        case .regex, .single: return !pattern.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func hydrate() {
        switch filter {
        case .all:                       mode = .all
        case .protectedOnly:             mode = .protectedOnly
        case .mine:                      mode = .mine
        case .regex(let p): mode = .regex;  pattern = p
        case .single(let r): mode = .single; pattern = r
        }
    }

    private func apply() {
        switch mode {
        case .all:           filter = .all
        case .protectedOnly: filter = .protectedOnly
        case .mine:          filter = .mine
        case .regex:         filter = .regex(pattern.trimmingCharacters(in: .whitespaces))
        case .single:        filter = .single(pattern.trimmingCharacters(in: .whitespaces))
        }
        onDone()
    }
}
