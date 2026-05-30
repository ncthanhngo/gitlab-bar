import SwiftUI
import AppKit

/// Popover tab that mints short-lived read-only **Group Access Tokens** to copy
/// for use elsewhere. Generated tokens persist (encrypted, via the Keychain on
/// `AppSettings`) and stay listed with a live countdown until they expire — at
/// which point `GeneratedTokenJanitor` revokes them server-side and removes
/// them locally.
///
/// Uses the connection's configured PAT as the creator credential (needs `api`
/// scope; the user must be Owner of the target group).
struct TokenGeneratorView: View {
    @EnvironmentObject private var settings: AppSettings

    enum Expiry: String, CaseIterable, Identifiable {
        case twoHours = "2h"
        case oneDay = "1d"
        var id: String { rawValue }
        var duration: TimeInterval {
            switch self {
            case .twoHours: return 2 * 3600
            case .oneDay:   return 24 * 3600
            }
        }
    }

    // Last-used preferences — devs reuse the same group/duration repeatedly.
    @AppStorage(AppConstants.DefaultsKey.lastTokenGroupID) private var lastGroupID: Int = 0
    @AppStorage(AppConstants.DefaultsKey.lastTokenExpiry)  private var lastExpiryRaw: String = Expiry.oneDay.rawValue

    @State private var groups: [GitLabGroup] = []
    @State private var isLoadingGroups = false
    @State private var groupsError: String?
    @State private var showGroupPicker = false
    @State private var groupFilter = ""

    @State private var isGenerating = false
    @State private var generateError: String?
    @State private var copiedID: UUID?
    @State private var revealed: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            if settings.makeClient() == nil {
                notConfiguredState
            } else {
                controlBar
                Divider()
                tokenList
            }
        }
        .task { await loadGroupsIfNeeded() }
    }

    // MARK: - Top control bar

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                groupPickerButton
                expiryPicker
                generateButton
            }
            if let generateError {
                Text(generateError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var groupPickerButton: some View {
        Button {
            showGroupPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                Text(selectedGroup?.fullPath ?? "Choose group…")
                    .lineLimit(1).truncationMode(.middle)
                Image(systemName: "chevron.down").imageScale(.small)
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showGroupPicker, arrowEdge: .bottom) {
            groupPickerPopover
        }
    }

    private var expiryPicker: some View {
        Picker("", selection: Binding(
            get: { Expiry(rawValue: lastExpiryRaw) ?? .oneDay },
            set: { lastExpiryRaw = $0.rawValue }
        )) {
            ForEach(Expiry.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 80)
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            if isGenerating {
                ProgressView().controlSize(.small)
            } else {
                Text("Generate")
            }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(isGenerating || selectedGroup == nil)
        .help("⌘↵ to generate")
    }

    // MARK: - Group picker popover

    private var groupPickerPopover: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary).imageScale(.small)
                TextField("Filter groups", text: $groupFilter)
                    .textFieldStyle(.plain)
                Button {
                    Task { await loadGroups() }
                } label: {
                    if isLoadingGroups {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise").imageScale(.small)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isLoadingGroups)
                .help("Reload")
            }
            .padding(8)

            Divider()

            if let groupsError {
                Text(groupsError).font(.caption).foregroundStyle(.red).padding(8)
            } else if filteredGroups.isEmpty {
                Text(groups.isEmpty ? "No Owner-level groups" : "No matches")
                    .font(.caption).foregroundStyle(.secondary).padding(8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredGroups) { g in groupRow(g) }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .frame(width: 280)
    }

    private func groupRow(_ g: GitLabGroup) -> some View {
        let selected = lastGroupID == g.id
        return Button {
            lastGroupID = g.id
            showGroupPicker = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selected ? "checkmark" : "")
                    .frame(width: 10).foregroundStyle(Color.accentColor)
                    .imageScale(.small)
                Text(g.fullPath).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Token list

    @ViewBuilder
    private var tokenList: some View {
        if activeTokens.isEmpty {
            emptyTokensState
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(activeTokens) { record in tokenRow(record) }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
        }
    }

    private func tokenRow(_ record: GeneratedTokenRecord) -> some View {
        let isRevealed = revealed.contains(record.id)
        let display = isRevealed ? record.token : Self.mask(record.token)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill").foregroundStyle(.secondary).imageScale(.small)
                Text(record.groupPath)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                countdown(for: record)
            }
            HStack(spacing: 6) {
                Group {
                    if isRevealed {
                        Text(display).textSelection(.enabled)
                    } else {
                        Text(display)
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                iconButton(copiedID == record.id ? "checkmark" : "doc.on.doc",
                           tint: copiedID == record.id ? .green : nil,
                           help: "Copy") {
                    copy(record)
                }
                iconButton(isRevealed ? "eye.slash" : "eye", help: isRevealed ? "Hide" : "Reveal") {
                    if isRevealed { revealed.remove(record.id) } else { revealed.insert(record.id) }
                }
                iconButton("trash", tint: .red, help: "Revoke") {
                    Task { await revokeAndRemove(record) }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
    }

    private func countdown(for record: GeneratedTokenRecord) -> some View {
        TimelineView(.periodic(from: Date(), by: 1)) { ctx in
            let remaining = record.effectiveExpiry.timeIntervalSince(ctx.date)
            let tint: Color = remaining < 5 * 60 ? .orange : .secondary
            Text(Self.formatRemaining(remaining))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private func iconButton(_ name: String, tint: Color? = nil, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .imageScale(.small)
                .foregroundStyle(tint ?? .primary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    // MARK: - Empty / not-configured states

    private var notConfiguredState: some View {
        VStack(spacing: 6) {
            Image(systemName: "gear").font(.title2).foregroundStyle(.secondary)
            Text("Not configured").font(.subheadline)
            Text("Set a GitLab URL and a PAT with the `api` scope in Settings → Connection.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(24)
    }

    private var emptyTokensState: some View {
        VStack(spacing: 6) {
            Image(systemName: "key").font(.title2).foregroundStyle(.secondary)
            Text("No active tokens").font(.subheadline)
            Text("Pick a group, choose 2h or 1d, hit Generate. The token is copied to your clipboard automatically.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity).padding(24)
    }

    // MARK: - Data

    private var selectedGroup: GitLabGroup? {
        groups.first { $0.id == lastGroupID }
    }

    private var activeTokens: [GeneratedTokenRecord] {
        settings.generatedTokens.filter { !$0.isExpired }.sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredGroups: [GitLabGroup] {
        let q = groupFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return groups }
        return groups.filter { $0.fullPath.lowercased().contains(q) }
    }

    private func loadGroupsIfNeeded() async {
        guard groups.isEmpty, settings.makeClient() != nil else { return }
        await loadGroups()
    }

    private func loadGroups() async {
        guard let client = settings.makeClient() else { return }
        isLoadingGroups = true
        groupsError = nil
        defer { isLoadingGroups = false }
        do {
            groups = try await client.administrableGroups(perPage: 100)
            if groups.isEmpty {
                groupsError = "No groups found where you have Owner access."
            } else if lastGroupID == 0 || !groups.contains(where: { $0.id == lastGroupID }) {
                lastGroupID = groups[0].id
            }
        } catch {
            groupsError = "Load failed: \(error.localizedDescription)"
        }
    }

    private func generate() async {
        guard let client = settings.makeClient(),
              let group = selectedGroup else { return }
        let expiry = Expiry(rawValue: lastExpiryRaw) ?? .oneDay
        isGenerating = true
        generateError = nil
        defer { isGenerating = false }

        let now = Date()
        // GitLab's `expires_at` only takes a day. Ask for tomorrow as the
        // upstream backstop; the app enforces the real (sub-day or 24h) cutoff
        // via the janitor — both options behave the same way for predictability.
        let cal = Calendar.current
        let upstream = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        let effective = now.addingTimeInterval(expiry.duration)
        let name = "gitlabbar-\(expiry.rawValue)-\(Self.hhmm(now))"

        do {
            let created = try await client.createGroupAccessToken(
                groupID: group.id,
                name: name,
                scope: AppConstants.TokenGenerator.scope,
                accessLevel: AppConstants.TokenGenerator.accessLevel,
                expiresAt: upstream)
            let record = GeneratedTokenRecord(
                id: UUID(),
                serverID: nil,
                groupID: group.id,
                groupPath: group.fullPath,
                gitlabTokenID: created.id,
                token: created.token,
                scope: created.scopes.first ?? AppConstants.TokenGenerator.scope,
                createdAt: now,
                effectiveExpiry: effective,
                needsRevoke: true)
            settings.addGeneratedToken(record)
            copy(record) // dev wants to paste it right away
        } catch let GitLabAPIError.http(status, _) where status == 403 {
            generateError = "403 — the configured PAT needs the `api` scope (not just `read_api`), and you must be Owner of this group."
        } catch let GitLabAPIError.http(status, body) {
            generateError = "HTTP \(status): \(body.prefix(160))"
        } catch {
            generateError = "Failed: \(error.localizedDescription)"
        }
    }

    private func copy(_ record: GeneratedTokenRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.token, forType: .string)
        let id = record.id
        copiedID = id
        Task {
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.TokenGenerator.copyFeedbackSecs * 1_000_000_000))
            if copiedID == id { copiedID = nil }
        }
    }

    private func revokeAndRemove(_ record: GeneratedTokenRecord) async {
        if let client = settings.makeClient(for: record.serverID) {
            try? await client.revokeGroupAccessToken(groupID: record.groupID,
                                                     tokenID: record.gitlabTokenID)
        }
        settings.removeGeneratedToken(id: record.id)
    }

    // MARK: - Formatting

    /// `glpat-•••••••••xxxx` — keep last 4 chars so the user can tell tokens
    /// apart without revealing the secret.
    private static func mask(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "•", count: token.count) }
        let prefix = token.prefix(while: { $0 != "-" })
        let suffix = String(token.suffix(4))
        let head = prefix.isEmpty ? "" : String(prefix) + "-"
        return head + String(repeating: "•", count: 8) + suffix
    }

    private static func formatRemaining(_ secs: TimeInterval) -> String {
        if secs <= 0 { return "expired" }
        let total = Int(secs)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    private static func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HHmm"
        return f.string(from: date)
    }
}
