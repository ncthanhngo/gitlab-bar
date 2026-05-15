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

    private var projectsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project ID or path `group/sub/name`. Prefer numeric IDs when possible.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                TextField("123 or group/subgroup/repo", text: $newProjectID)
                    .textFieldStyle(.roundedBorder)
                TextField("Display name (optional)", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addProject() }
                    .disabled(newProjectID.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(settings.projects) { project in
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(project.displayName).font(.system(size: 13))
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
            .frame(minHeight: 200)
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
