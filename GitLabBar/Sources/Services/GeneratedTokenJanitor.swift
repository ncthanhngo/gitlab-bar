import Foundation
import Combine

/// Periodically prunes generated tokens that have reached their effective
/// expiry. Day-based tokens are simply dropped (GitLab already expired them);
/// "2 hours" tokens still live on GitLab, so they are revoked first.
///
/// Runs on launch and every `janitorIntervalSecs`. A failed revoke keeps the
/// record so it can be retried next tick rather than leaking a live token.
@MainActor
final class GeneratedTokenJanitor: ObservableObject {
    private let settings: AppSettings
    private var pollTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.purge()
                let secs = AppConstants.TokenGenerator.janitorIntervalSecs
                try? await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Drop expired records, revoking GitLab-side first when required.
    func purge() async {
        for record in settings.generatedTokens where record.isExpired {
            if record.needsRevoke {
                guard let client = settings.makeClient(for: record.serverID) else { continue }
                do {
                    try await client.revokeGroupAccessToken(groupID: record.groupID,
                                                            tokenID: record.gitlabTokenID)
                } catch {
                    // Keep the record; retry on the next tick so we don't leak it.
                    AppLogger.settings.error("revoke of generated token failed: \(error.localizedDescription, privacy: .public)")
                    continue
                }
            }
            settings.removeGeneratedToken(id: record.id)
        }
    }
}
