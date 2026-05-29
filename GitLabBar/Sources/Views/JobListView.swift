import SwiftUI
import AppKit

/// Inline expansion shown when the user clicks a pipeline's chevron.
/// Lazily loads jobs once per (project, pipeline) and renders a small
/// stage-duration bar (Phase 05) above the job list.
struct JobListView: View {
    let entry: PipelineEntry

    @EnvironmentObject private var settings: AppSettings
    @State private var jobs: [PipelineJob] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLoading && jobs.isEmpty {
                HStack { ProgressView().controlSize(.small); Text("Loading jobs…").font(.caption) }
                    .padding(.leading, 28)
            } else if let loadError {
                Text(loadError)
                    .font(.caption).foregroundStyle(.red)
                    .padding(.leading, 28)
            } else if jobs.isEmpty {
                Text("No jobs.").font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 28)
            } else {
                if stageGroups.count >= 2 {
                    StageDurationBarView(jobs: jobs)
                        .padding(.leading, 28)
                        .padding(.trailing, 8)
                }
                ForEach(sortedJobs) { job in
                    JobRowView(job: job)
                }
            }
        }
        .task(id: entry.id) { await load() }
    }

    private var sortedJobs: [PipelineJob] {
        // Failed first, then preserve stage order from API.
        jobs.sorted { lhs, rhs in
            let lf = lhs.status == .failed ? 0 : 1
            let rf = rhs.status == .failed ? 0 : 1
            return lf < rf
        }
    }

    private var stageGroups: [String] {
        Array(Set(jobs.map(\.stage)))
    }

    private func load() async {
        guard !isLoading else { return }
        guard let client = settings.makeClient() else {
            loadError = "Not configured."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await client.pipelineJobs(projectID: entry.project.id, pipelineID: entry.pipeline.id)
        } catch {
            loadError = error.localizedDescription
        }
    }
}
