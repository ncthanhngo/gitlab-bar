import SwiftUI

/// Display-ready bundle for a single project block in the popover.
struct ProjectSection: Identifiable {
    let id: String
    let name: String
    let entries: [PipelineEntry]
    let summary: ProjectSummary
}

/// Per-project status rollup used to colour the section header, show a count
/// chip, and sort projects so the ones the user cares about (running, failed)
/// always appear at the top of the popover.
struct ProjectSummary {
    let icon: String
    let tint: Color
    let runningCount: Int
    let failedCount: Int
    let successCount: Int
    /// Lower number → higher in the list. 0=running, 1=failed, 2=green, 3=other.
    let priority: Int

    /// Short label rendered next to the project name (e.g. `2 running · 1 failed`).
    /// `nil` when the project is fully green / idle, to avoid noise.
    var countLabel: String? {
        var parts: [String] = []
        if runningCount > 0 { parts.append("\(runningCount) running") }
        if failedCount  > 0 { parts.append("\(failedCount) failed") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Build a summary from this project's pipeline entries.
    /// The "most recent" pipeline (entries are pre-sorted newest first by the
    /// monitor) drives the priority when nothing is actively running.
    static func from(entries: [PipelineEntry]) -> ProjectSummary {
        var running = 0
        var failed  = 0
        var success = 0
        for entry in entries {
            switch entry.pipeline.status {
            case .running, .pending, .preparing, .created, .waitingForResource, .scheduled:
                running += 1
            case .failed:
                failed += 1
            case .success:
                success += 1
            case .canceled, .skipped, .manual:
                break
            }
        }

        let latest = entries.first?.pipeline.status
        let icon: String
        let tint: Color
        let priority: Int

        if running > 0 {
            icon = "arrow.triangle.2.circlepath"
            tint = .orange
            priority = 0
        } else if latest == .failed {
            icon = "xmark.octagon.fill"
            tint = .red
            priority = 1
        } else if latest == .success {
            icon = "checkmark.circle.fill"
            tint = .green
            priority = 2
        } else {
            icon = "circle.dotted"
            tint = .secondary
            priority = 3
        }

        return ProjectSummary(
            icon: icon,
            tint: tint,
            runningCount: running,
            failedCount: failed,
            successCount: success,
            priority: priority
        )
    }
}
