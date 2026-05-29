import SwiftUI

/// A horizontal stacked bar showing per-stage total duration, proportional widths.
/// Stages with < 1% of total time collapse into a neutral "other" segment.
struct StageDurationBarView: View {
    let jobs: [PipelineJob]

    var body: some View {
        let groups = stageGroups()
        if groups.isEmpty {
            EmptyView()
        } else {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(groups, id: \.stage) { g in
                        let width = max(2, geo.size.width * g.fraction)
                        Rectangle()
                            .fill(stageColor(g.stage).opacity(0.75))
                            .frame(width: width)
                            .help("\(g.stage): \(format(seconds: g.totalSeconds))")
                            .overlay(alignment: .leading) {
                                if width > 38 {
                                    Text(g.stage)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.leading, 4)
                                        .lineLimit(1)
                                }
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 12)
        }
    }

    private struct StageGroup {
        let stage: String
        let totalSeconds: Int
        let fraction: Double
    }

    private func stageGroups() -> [StageGroup] {
        var totals: [String: Int] = [:]
        for j in jobs where j.status != .skipped {
            guard let d = j.durationSeconds, d > 0 else { continue }
            totals[j.stage, default: 0] += d
        }
        let total = max(1, totals.values.reduce(0, +))
        let ordered = totals.sorted { $0.value > $1.value }
        return ordered.map { StageGroup(stage: $0.key,
                                        totalSeconds: $0.value,
                                        fraction: Double($0.value) / Double(total)) }
    }

    private func format(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
