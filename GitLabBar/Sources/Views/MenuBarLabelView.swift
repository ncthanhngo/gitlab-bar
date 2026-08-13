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
/// - **running** — the same dotted circle in orange, rotating one turn every
///   two seconds, followed by a 3-character uppercase abbreviation of the
///   most-recently running project (plus `·N` when several projects are busy
///   at once).
struct MenuBarLabelView: View {
    let state: MenuBarState

    /// Which pre-rendered frame of the spinner is currently on screen.
    @State private var spinFrame = 0

    /// Drives the spinner by stepping `spinFrame`. Declared per-instance rather
    /// than statically so the subscription — and with it the timer — goes away
    /// as soon as the view leaves the `running` branch.
    private let spinClock = Timer
        .publish(every: Self.spinInterval, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        switch state {
        case .idle:
            Image(nsImage: Self.idleCircle)

        case .running(let abbreviation, let count):
            HStack(spacing: 3) {
                Image(nsImage: Self.spinFrames[spinFrame])
                Text(count > 1 ? "\(abbreviation)·\(count)" : abbreviation)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .onReceive(spinClock) { _ in
                spinFrame = (spinFrame + 1) % Self.spinFrames.count
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

    /// Number of frames in one full turn of the spinner, and how long each is
    /// held. Together they keep the original two-second revolution.
    ///
    /// A SwiftUI `repeatForever` animation would be the obvious way to spin the
    /// icon, but the menu bar label is on screen permanently, so an endless
    /// animation pins the display link and re-runs the whole SwiftUI layout
    /// pass every display cycle for as long as the app runs. Swapping between
    /// pre-rendered images on a timer costs one layout pass per frame instead.
    private static let spinFrameCount = 24
    private static let spinInterval: TimeInterval = 2.0 / Double(spinFrameCount)

    private static let idleCircle: NSImage   = makeDottedCircle(color: .systemGreen)
    private static let failedCircle: NSImage = makeFilledCircle(color: .systemRed)

    /// One dotted circle per rotation step. 24 frames of a 14pt glyph is a few
    /// kilobytes, so they are all built once at first use.
    private static let spinFrames: [NSImage] = (0..<spinFrameCount).map { step in
        makeDottedCircle(
            color: .systemOrange,
            rotationDegrees: CGFloat(step) * 360 / CGFloat(spinFrameCount)
        )
    }

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
    ///
    /// `rotationDegrees` turns the dash pattern about the centre, which is how
    /// the spinner frames are produced.
    private static func makeDottedCircle(color: NSColor, rotationDegrees: CGFloat = 0) -> NSImage {
        let side: CGFloat = 14
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        if rotationDegrees != 0 {
            let turn = NSAffineTransform()
            turn.translateX(by: side / 2, yBy: side / 2)
            turn.rotate(byDegrees: rotationDegrees)
            turn.translateX(by: -side / 2, yBy: -side / 2)
            turn.concat()
        }
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
