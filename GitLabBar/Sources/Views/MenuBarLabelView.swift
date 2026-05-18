import SwiftUI
import AppKit

/// What the menu bar shows. Either a calm green dot or an animated orange
/// indicator with a short abbreviation of the most recently active project.
enum MenuBarState: Equatable {
    case idle
    case running(abbreviation: String, count: Int)
    /// At least one pipeline failed and the user hasn't opened the popover yet.
    case failed(count: Int)
}

/// The compact view rendered inside the system menu bar slot.
///
/// macOS forces every menu-bar image through a template path that strips
/// colour to white/black. SwiftUI `Image(systemName:)` and even SwiftUI
/// `Circle().stroke(.green, …)` get caught by this. The only reliable way to
/// show actual colour is to draw the glyph into an `NSImage`, mark it
/// `isTemplate = false`, and feed that into `Image(nsImage:)`.
///
/// States:
/// - **idle** — a green dotted circle, no animation.
/// - **running** — the same dotted circle in orange, continuously rotating,
///   followed by a 3-character uppercase abbreviation of the most-recently
///   running project (plus `·N` when several projects are busy at once).
struct MenuBarLabelView: View {
    let state: MenuBarState

    @State private var rotation: Double = 0

    var body: some View {
        switch state {
        case .idle:
            Image(nsImage: Self.idleCircle)

        case .running(let abbreviation, let count):
            HStack(spacing: 3) {
                Image(nsImage: Self.runningCircle)
                    .rotationEffect(.degrees(rotation))
                    .onAppear { startRotating() }
                Text(count > 1 ? "\(abbreviation)·\(count)" : abbreviation)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

        case .failed(let count):
            HStack(spacing: 3) {
                Image(nsImage: Self.failedCircle)
                Text(count > 1 ? "FAIL·\(count)" : "FAIL")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .monospacedDigit()
            }
        }
    }

    private func startRotating() {
        // Restart from zero so consecutive activations spin smoothly.
        rotation = 0
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotation = 360
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

    // MARK: - Pre-rendered NSImages

    private static let idleCircle: NSImage    = makeDottedCircle(color: .systemGreen)
    private static let runningCircle: NSImage = makeDottedCircle(color: .systemOrange)
    private static let failedCircle: NSImage  = makeFilledCircle(color: .systemRed)

    /// Solid filled circle used by the `failed` state. We swap shape (filled vs
    /// dashed outline) on top of colour so the alert reads even for colour-blind
    /// users.
    private static func makeFilledCircle(color: NSColor) -> NSImage {
        let side: CGFloat = 14
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let inset: CGFloat = 1.5
        let rect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        let path = NSBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// Draws a dashed circle into an `NSImage` and disables template treatment
    /// so the system keeps the colour we asked for.
    private static func makeDottedCircle(color: NSColor) -> NSImage {
        let side: CGFloat = 14
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        let inset: CGFloat = 1.5
        let rect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        let dash: [CGFloat] = [0.5, 2.6]
        path.setLineDash(dash, count: dash.count, phase: 0)
        color.setStroke()
        path.stroke()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
