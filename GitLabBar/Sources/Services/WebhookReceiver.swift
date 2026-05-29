import Foundation
import Network

/// Tiny HTTP/1.1 listener bound to 127.0.0.1.
/// User exposes it publicly via Tailscale Funnel / cloudflared / ngrok (out of scope).
/// On every accepted POST, verifies `X-Gitlab-Token` and forwards a decoded
/// `PipelineWebhookPayload` to its `onEvent` closure.
@MainActor
final class WebhookReceiver {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "gitlabbar.webhook")
    private(set) var lastEventAt: Date?
    private(set) var isRunning = false

    var onEvent: (@MainActor (PipelineWebhookPayload) -> Void)?

    func start(port: UInt16, secret: String) throws {
        stop()
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: AppConstants.Webhook.defaultPort)!
        let listener = try NWListener(using: params, on: nwPort)
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(connection: conn, secret: secret)
        }
        listener.start(queue: queue)
        self.listener = listener
        self.isRunning = true
        AppLogger.api.info("webhook receiver listening on 127.0.0.1:\(port, privacy: .public)")
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private nonisolated func handle(connection: NWConnection, secret: String) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            defer { connection.cancel() }
            guard let data, !data.isEmpty,
                  let raw = String(data: data, encoding: .utf8) else { return }
            // Parse minimal HTTP request: header block / body block.
            guard let parts = Self.splitHTTP(raw) else { return }
            let headers = parts.headers
            let body    = parts.body

            // Verify shared secret.
            let token = headers["x-gitlab-token"] ?? headers["X-Gitlab-Token"]
            guard token == secret else {
                Self.respond(connection: connection, status: "403 Forbidden")
                return
            }
            guard let bodyData = body.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(PipelineWebhookPayload.self, from: bodyData),
                  payload.objectKind == "pipeline" else {
                Self.respond(connection: connection, status: "400 Bad Request")
                return
            }
            Self.respond(connection: connection, status: "200 OK")
            Task { @MainActor [weak self] in
                self?.lastEventAt = Date()
                self?.onEvent?(payload)
            }
        }
    }

    private nonisolated static func splitHTTP(_ raw: String) -> (headers: [String: String], body: String)? {
        guard let sep = raw.range(of: "\r\n\r\n") else { return nil }
        let head = raw[raw.startIndex..<sep.lowerBound]
        let body = String(raw[sep.upperBound...])
        var headers: [String: String] = [:]
        for line in head.split(separator: "\r\n").dropFirst() {
            if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].lowercased()
                var val = String(line[line.index(after: colon)...])
                val = val.trimmingCharacters(in: .whitespaces)
                headers[String(key)] = val
            }
        }
        return (headers, body)
    }

    private nonisolated static func respond(connection: NWConnection, status: String) {
        let body = ""
        let response = "HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in })
    }
}
