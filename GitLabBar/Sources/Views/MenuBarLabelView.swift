import SwiftUI

/// What the menu bar shows. Either a calm green dot or an animated orange
/// indicator with a short abbreviation of the most recently active project.
enum MenuBarState: Equatable {
    case idle
    case running(abbreviation: String, count: Int)
}

/// The compact view rendered inside the system menu bar slot.
///
/// We deliberately avoid `Image(systemName:)` here because macOS treats menu
/// bar images as template artwork and strips colour — `.foregroundStyle(.green)`
/// gets ignored and the symbol appears white. Drawing the circle with a
/// SwiftUI `Circle` shape sidesteps the template path entirely, so the green /
/// orange tint is honoured.
///
/// States:
/// - **idle** — a dashed green circle, no animation.
/// - **running** — the same dashed circle rendered in orange and continuously
///   rotating, followed by a 3-character uppercase abbreviation of the
///   most-recently-running project (plus a `·N` counter when several projects
///   are busy at once).
struct MenuBarLabelView: View {
    let state: MenuBarState

    var body: some View {
        switch state {
        case .idle:
            DottedCircleIndicator(color: .green, animated: false)

        case .running(let abbreviation, let count):
            HStack(spacing: 3) {
                DottedCircleIndicator(color: .orange, animated: true)
                Text(count > 1 ? "\(abbreviation)·\(count)" : abbreviation)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
        }
    }

    /// Build a short uppercase tag from a project display name. We prefer the
    /// last path segment so `myorg/web-frontend` becomes `WEB`, not `MYO`.
    static func abbreviate(_ projectName: String) -> String {
        let leaf = projectName
            .split(separator: "/")
            .last
            .map(String.init) ?? projectName
        let cleaned = leaf.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(Character.init)
        let head = String(cleaned.prefix(3))
        return head.isEmpty ? "···" : head.uppercased()
    }
}

/// A dashed circle drawn with `Circle` + `StrokeStyle.dash`, so its colour
/// survives the menu bar's template-image treatment. When `animated`, the
/// shape rotates indefinitely to communicate "work in progress".
private struct DottedCircleIndicator: View {
    let color: Color
    let animated: Bool

    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: 1.6,
                    lineCap: .round,
                    dash: [0.1, 2.6]
                )
            )
            .frame(width: 13, height: 13)
            .rotationEffect(.degrees(rotation))
            .onAppear { applyAnimation(animated) }
            .modifier(AnimatedChangeModifier(value: animated, apply: applyAnimation))
    }

    private func applyAnimation(_ on: Bool) {
        if on {
            // Reset to a deterministic starting angle so subsequent transitions
            // don't accumulate weird offsets across state changes.
            rotation = 0
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else {
            withAnimation(.default) { rotation = 0 }
        }
    }
}

/// Tiny shim that uses the two-argument `onChange` on macOS 14+ and the
/// older single-argument form on macOS 13. Keeps the parent view ergonomic.
private struct AnimatedChangeModifier: ViewModifier {
    let value: Bool
    let apply: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14, *) {
            content.onChange(of: value) { _, newValue in apply(newValue) }
        } else {
            content.onChange(of: value) { newValue in apply(newValue) }
        }
    }
}
