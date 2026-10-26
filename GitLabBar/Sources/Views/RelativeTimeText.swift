import SwiftUI

/// Minute-granularity relative time ("5 min. ago").
///
/// `Text(date, style: .relative)` counts seconds, so it re-renders every
/// second — and `MenuBarExtra(.window)` keeps its content view live while the
/// popover is closed, so a handful of those kept the app at ~10% CPU when idle.
/// This view refreshes once a minute instead.
struct RelativeTimeText: View {
    let date: Date
    var prefix: String = ""

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(prefix + Self.describe(date, relativeTo: context.date))
        }
    }

    static func describe(_ date: Date, relativeTo now: Date) -> String {
        // Seconds would freeze between minute ticks, so collapse them.
        if abs(now.timeIntervalSince(date)) < 60 { return "just now" }
        return formatter.localizedString(for: date, relativeTo: now)
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
