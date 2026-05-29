import SwiftUI

/// The MR-centric secondary popover content: "Mine" + "Review requests" sections.
struct MRListView: View {
    @EnvironmentObject private var mrMonitor: MRMonitor
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        if settings.makeClient() == nil {
            empty("gear", "Not configured", "Open Settings to enter URL and token.")
        } else if mrMonitor.mine.isEmpty && mrMonitor.reviewRequests.isEmpty {
            if mrMonitor.lastRefresh == nil {
                empty("hourglass", "Loading…", nil)
            } else {
                empty("checkmark.circle", "Inbox zero", "No open MRs.")
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !mrMonitor.mine.isEmpty {
                        section("Mine", count: mrMonitor.mine.count, mrs: mrMonitor.mine)
                    }
                    if !mrMonitor.reviewRequests.isEmpty {
                        section("Review requests", count: mrMonitor.reviewRequests.count, mrs: mrMonitor.reviewRequests)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 420)
        }
    }

    private func section(_ title: String, count: Int, mrs: [MergeRequest]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Text("(\(count))").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            ForEach(mrs) { MRRowView(mr: $0) }
        }
    }

    private func empty(_ icon: String, _ title: String, _ detail: String?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
            Text(title).font(.subheadline)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
