import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: PipelineMonitor

    @State private var newProjectID: String = ""
    @State private var newProjectName: String = ""
    @State private var connectionMessage: String?
    @State private var isTesting = false

    var body: some View {
        TabView {
            connectionTab.tabItem { Label("Connection", systemImage: "network") }
            projectsTab.tabItem  { Label("Projects",  systemImage: "folder") }
            generalTab.tabItem   { Label("General",   systemImage: "gear") }
        }
        .padding(16)
    }

    // MARK: - Connection tab

    private var connectionTab: some View {
        Form {
            Section {
                TextField("GitLab base URL",
                          text: $settings.gitlabBaseURL,
                          prompt: Text("https://gitlab.company.com"))
                    .textFieldStyle(.roundedBorder)
                SecureField("Personal Access Token",
                            text: $settings.token,
                            prompt: Text("glpat-…"))
                    .textFieldStyle(.roundedBorder)
                Text("The token needs the `read_api` scope. It is stored in the macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Self-hosted GitLab").font(.headline)
            }

            Section {
                HStack {
                    Button(isTesting ? "Testing…" : "Test connection") {
                        Task { await testConnection() }
                    }
                    .disabled(isTesting || settings.makeClient() == nil)

                    if let msg = connectionMessage {
                        Text(msg).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func testConnection() async {
        guard let client = settings.makeClient() else { return }
        isTesting = true
        defer { isTesting = false }
        // If user has any project, try one. Otherwise, hit `/user` via projects list.
        if let firstID = settings.projects.first?.id {
            do {
                let info = try await client.projectInfo(projectID: firstID)
                connectionMessage = "OK – \(info.pathWithNamespace)"
            } catch {
                connectionMessage = "Error: \(error.localizedDescription)"
            }
        } else {
            // No project configured – just verify URL/token shape.
            connectionMessage = "URL and token set. Add a project to run a real test."
        }
        await monitor.refresh()
    }

    // MARK: - Projects tab

    @State private var availableProjects: [GitLabProjectInfo] = []
    @State private var isLoadingProjects = false
    @State private var projectsError: String?
    @State private var browseSearch: String = ""

    private var projectsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            browseHeader
            browseList
            if !manualOnlyEntries.isEmpty {
                Divider().padding(.vertical, 2)
                manualEntriesSection
            }
            Divider().padding(.vertical, 2)
            manualAddRow
        }
        .task { await loadProjectsIfNeeded() }
    }

    // MARK: Browse section

    private var browseHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("My GitLab projects").font(.headline)
                if !availableProjects.isEmpty {
                    Text("(\(availableProjects.count))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await loadProjects() }
                } label: {
                    if isLoadingProjects {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isLoadingProjects || settings.makeClient() == nil)
                .help("Reload list from GitLab")
            }
            if settings.makeClient() == nil {
                Text("Enter the GitLab URL and token in the Connection tab first.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Filter by name or path", text: $browseSearch)
                    .textFieldStyle(.roundedBorder)
                if let projectsError {
                    Text(projectsError).font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var browseList: some View {
        if settings.makeClient() == nil {
            placeholder("Not configured")
        } else if availableProjects.isEmpty && !isLoadingProjects {
            placeholder("No projects loaded yet — click the refresh icon.")
        } else {
            List {
                ForEach(filteredAvailableProjects, id: \.id) { info in
                    browseRow(info)
                }
            }
            .frame(minHeight: 160)
        }
    }

    private func browseRow(_ info: GitLabProjectInfo) -> some View {
        let watching = isWatching(info)
        return HStack(spacing: 8) {
            Button {
                toggleWatch(info)
            } label: {
                Image(systemName: watching ? "star.fill" : "star")
                    .foregroundStyle(watching ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            .help(watching ? "Stop watching" : "Watch this project")

            VStack(alignment: .leading, spacing: 1) {
                Text(info.pathWithNamespace).font(.system(size: 12))
                Text("#\(info.id)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleWatch(info) }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    // MARK: Manual entries that aren't covered by the browse list

    private var manualOnlyEntries: [ProjectConfig] {
        let browseIDs = Set(availableProjects.map { "\($0.id)" })
        return settings.projects.filter { !browseIDs.contains($0.id) }
    }

    private var manualEntriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manually added").font(.subheadline)
            ForEach(manualOnlyEntries) { project in
                HStack {
                    Image(systemName: "folder").foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(project.displayName).font(.system(size: 12))
                        if project.displayName != project.id {
                            Text(project.id).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        if let idx = settings.projects.firstIndex(of: project) {
                            settings.removeProject(at: IndexSet(integer: idx))
                            Task { await monitor.refresh() }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: Manual add

    private var manualAddRow: some View {
        HStack {
            Text("Add manually:").font(.caption).foregroundStyle(.secondary)
            TextField("ID or group/subgroup/repo", text: $newProjectID)
                .textFieldStyle(.roundedBorder)
            Button("Add") { addProject() }
                .disabled(newProjectID.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: Actions

    private func loadProjectsIfNeeded() async {
        guard availableProjects.isEmpty, settings.makeClient() != nil else { return }
        await loadProjects()
    }

    private func loadProjects() async {
        guard let client = settings.makeClient() else {
            projectsError = "Not configured."
            return
        }
        isLoadingProjects = true
        projectsError = nil
        defer { isLoadingProjects = false }
        do {
            availableProjects = try await client.userProjects(perPage: 100)
        } catch {
            projectsError = "Load failed: \(error.localizedDescription)"
        }
    }

    private func toggleWatch(_ info: GitLabProjectInfo) {
        let id = "\(info.id)"
        if let idx = settings.projects.firstIndex(where: { $0.id == id }) {
            settings.removeProject(at: IndexSet(integer: idx))
        } else {
            settings.addProject(ProjectConfig(id: id, displayName: info.pathWithNamespace))
        }
        Task { await monitor.refresh() }
    }

    private func isWatching(_ info: GitLabProjectInfo) -> Bool {
        settings.projects.contains { $0.id == "\(info.id)" }
    }

    private var filteredAvailableProjects: [GitLabProjectInfo] {
        let q = browseSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return availableProjects }
        return availableProjects.filter {
            $0.name.lowercased().contains(q) ||
            $0.pathWithNamespace.lowercased().contains(q)
        }
    }

    private func addProject() {
        let id = newProjectID.trimmingCharacters(in: .whitespaces)
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        settings.addProject(ProjectConfig(id: id, displayName: name.isEmpty ? id : name))
        newProjectID = ""
        newProjectName = ""
        Task { await monitor.refresh() }
    }

    // MARK: - General tab

    @State private var launchAtLoginOn: Bool = LaunchAtLoginService.isEnabled
    @State private var launchAtLoginError: String?

    private var generalTab: some View {
        Form {
            Section {
                Stepper(value: $settings.pollIntervalSecs,
                        in: AppConstants.Default.minPollSeconds...AppConstants.Default.maxPollSeconds,
                        step: 5) {
                    Text("Refresh every \(settings.pollIntervalSecs)s")
                }
                Stepper(value: $settings.perPage, in: 1...50) {
                    Text("Show \(settings.perPage) pipelines / project")
                }
            } header: {
                Text("Polling").font(.headline)
            }

            Section {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                Toggle("Notify on failed", isOn: $settings.notifyOnFailed)
                    .disabled(!settings.notificationsEnabled)
                Toggle("Notify on success", isOn: $settings.notifyOnSuccess)
                    .disabled(!settings.notificationsEnabled)
                Text("Banners fire when a pipeline transitions from running to a terminal state.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Notifications").font(.headline)
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLoginOn)
                    .onChange(of: launchAtLoginOn) { newValue in
                        do {
                            try LaunchAtLoginService.setEnabled(newValue)
                            launchAtLoginError = nil
                        } catch {
                            launchAtLoginError = error.localizedDescription
                            // Roll the toggle back so UI reflects real state.
                            launchAtLoginOn = LaunchAtLoginService.isEnabled
                        }
                    }
                if let msg = launchAtLoginError {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Startup").font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}
