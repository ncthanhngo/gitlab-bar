import SwiftUI
import AppKit

/// Settings section for the optional webhook receiver mode.
struct WebhookSetupView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var revealSecret = false
    @State private var status: String?

    var body: some View {
        Section {
            Toggle("Enable webhook receiver", isOn: $settings.webhookEnabled)
                .help("Listens on 127.0.0.1. Expose via Tailscale Funnel / cloudflared.")
            Stepper(value: $settings.webhookPort, in: 1024...65535) {
                Text("Port: \(settings.webhookPort)").monospacedDigit()
            }
            .disabled(!settings.webhookEnabled)

            HStack {
                Text("Secret:")
                Text(displaySecret)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                Button(revealSecret ? "Hide" : "Reveal") { revealSecret.toggle() }
                    .buttonStyle(.borderless)
                Button("Copy") { copy(settings.ensureWebhookSecret()) }
                    .buttonStyle(.borderless)
                Button("Rotate") {
                    settings.webhookSecret = ""
                    _ = settings.ensureWebhookSecret()
                }
                .buttonStyle(.borderless)
            }
            .disabled(!settings.webhookEnabled)

            Text("In GitLab → Settings → Webhooks, paste your public URL (e.g. https://you.ts.net) and the secret above. Enable `Pipeline events`.")
                .font(.caption).foregroundStyle(.secondary)

            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Webhook receiver").font(.headline)
        }
    }

    private var displaySecret: String {
        let secret = settings.webhookSecret
        if secret.isEmpty { return "(generated on enable)" }
        if revealSecret { return secret }
        return String(repeating: "•", count: min(secret.count, 12))
    }

    private func copy(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
        status = "Secret copied"
    }
}
