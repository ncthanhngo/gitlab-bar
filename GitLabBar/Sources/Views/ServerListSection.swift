import SwiftUI

/// Settings section managing additional GitLab servers (multi-instance).
/// The legacy single-server config still works for users who only have one.
struct ServerListSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: PipelineMonitor

    @State private var newName: String = ""
    @State private var newURL: String = ""
    @State private var newToken: String = ""

    var body: some View {
        Section {
            ForEach(settings.servers) { server in
                row(server)
            }
            Divider().padding(.vertical, 2)
            addForm
        } header: {
            HStack {
                Text("Additional GitLab servers").font(.headline)
                Text("(multi-instance)").font(.caption).foregroundStyle(.secondary)
            }
        } footer: {
            Text("Each project can be pinned to one server. Projects without a pin use the GitLab URL/token above.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func row(_ server: ServerConfig) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "server.rack").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(server.name).font(.system(size: 12, weight: .medium))
                Text(server.url).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            SecureField("PAT", text: Binding(
                get: { settings.serverTokens[server.id] ?? "" },
                set: { settings.serverTokens[server.id] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 140)
            Button {
                settings.removeServer(id: server.id)
                Task { await monitor.refresh() }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private var addForm: some View {
        VStack(spacing: 6) {
            HStack {
                TextField("Label (e.g. gitlab.com)", text: $newName)
                TextField("https://gitlab.example.com", text: $newURL)
            }
            HStack {
                SecureField("Personal Access Token", text: $newToken)
                Button("Add server") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    let url  = newURL.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, !url.isEmpty else { return }
                    settings.addServer(ServerConfig(name: name, url: url), token: newToken)
                    newName = ""; newURL = ""; newToken = ""
                    Task { await monitor.refresh() }
                }
                .disabled(newName.isEmpty || newURL.isEmpty)
            }
        }
        .textFieldStyle(.roundedBorder)
    }
}
