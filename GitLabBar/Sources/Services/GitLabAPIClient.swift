import Foundation

/// `URLSession`-backed implementation of `GitLabAPI`.
///
/// Only the endpoints required by the widget are exposed:
/// - list latest pipelines per project
/// - fetch basic project info (for nicer display names)
struct GitLabAPIClient: GitLabAPI {
    let baseURL: URL
    let token: String
    let session: URLSession

    init(baseURL: URL, token: String, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.token = token
        self.session = session ?? Self.makeSession()
    }

    /// Dedicated session so we don't inherit `URLSession.shared`'s pooled
    /// connections — which can survive nsurlsessiond hangs across app launches.
    private static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest  = AppConstants.Default.requestTimeout
        cfg.timeoutIntervalForResource = AppConstants.Default.requestTimeout
        cfg.waitsForConnectivity = false
        cfg.httpMaximumConnectionsPerHost = 4
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }

    // MARK: - GitLabAPI

    func recentPipelines(projectID: String, perPage: Int = AppConstants.Default.perPage) async throws -> [Pipeline] {
        try await recentPipelines(projectID: projectID, ref: nil, perPage: perPage)
    }

    func recentPipelines(projectID: String, ref: String?, perPage: Int) async throws -> [Pipeline] {
        let encoded = Self.encode(projectID)
        let path = String(format: AppConstants.API.pipelinesPath, encoded)
        var query: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "order_by", value: "updated_at"),
            URLQueryItem(name: "sort", value: "desc"),
        ]
        if let ref, !ref.isEmpty {
            query.append(URLQueryItem(name: "ref", value: ref))
        }
        let url = try makeURL(path: path, query: query)
        return try await get(url: url)
    }

    func pipelineJobs(projectID: String, pipelineID: Int) async throws -> [PipelineJob] {
        let encoded = Self.encode(projectID)
        let path = String(format: AppConstants.API.pipelineJobsPath, encoded, pipelineID)
        let url = try makeURL(path: path, query: [
            URLQueryItem(name: "per_page", value: "100"),
        ])
        return try await get(url: url)
    }

    func retryPipeline(projectID: String, pipelineID: Int) async throws {
        let encoded = Self.encode(projectID)
        let path = String(format: AppConstants.API.pipelineRetryPath, encoded, pipelineID)
        let url = try makeURL(path: path, query: [])
        try await post(url: url)
    }

    func cancelPipeline(projectID: String, pipelineID: Int) async throws {
        let encoded = Self.encode(projectID)
        let path = String(format: AppConstants.API.pipelineCancelPath, encoded, pipelineID)
        let url = try makeURL(path: path, query: [])
        try await post(url: url)
    }

    func currentUser() async throws -> GitLabUser {
        let url = try makeURL(path: AppConstants.API.userPath, query: [])
        return try await get(url: url)
    }

    func mergeRequests(scope: MRScope) async throws -> [MergeRequest] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "state", value: "opened"),
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "order_by", value: "updated_at"),
            URLQueryItem(name: "sort", value: "desc"),
            URLQueryItem(name: "with_labels_details", value: "false"),
        ]
        switch scope {
        case .createdByMe:
            query.append(URLQueryItem(name: "scope", value: "created_by_me"))
        case .reviewer:
            query.append(URLQueryItem(name: "reviewer_username", value: "@me"))
        }
        let url = try makeURL(path: AppConstants.API.mergeRequestsPath, query: query)
        return try await get(url: url)
    }

    func projectInfo(projectID: String) async throws -> GitLabProjectInfo {
        let encoded = Self.encode(projectID)
        let path = String(format: AppConstants.API.projectPath, encoded)
        let url = try makeURL(path: path, query: [])
        return try await get(url: url)
    }

    func userProjects(perPage: Int = 100) async throws -> [GitLabProjectInfo] {
        let url = try makeURL(path: AppConstants.API.projectsListPath, query: [
            URLQueryItem(name: "membership", value: "true"),
            URLQueryItem(name: "simple", value: "true"),
            URLQueryItem(name: "archived", value: "false"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "order_by", value: "last_activity_at"),
            URLQueryItem(name: "sort", value: "desc"),
        ])
        return try await get(url: url)
    }

    // MARK: - Internals

    private func post(url: URL) async throws {
        var req = URLRequest(url: url,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: AppConstants.Default.requestTimeout)
        req.httpMethod = "POST"
        req.setValue(token, forHTTPHeaderField: AppConstants.API.tokenHeader)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw GitLabAPIError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitLabAPIError.http(status: http.statusCode, body: body)
        }
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: AppConstants.Default.requestTimeout)
        req.httpMethod = "GET"
        req.setValue(token, forHTTPHeaderField: AppConstants.API.tokenHeader)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            AppLogger.api.error("transport error for \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw GitLabAPIError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            AppLogger.api.error("HTTP \(http.statusCode) for \(url.path, privacy: .public)")
            throw GitLabAPIError.http(status: http.statusCode, body: body)
        }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            AppLogger.api.error("decoding error for \(T.self): \(error.localizedDescription, privacy: .public)")
            throw GitLabAPIError.decoding(error)
        }
    }

    /// Build a URL by appending `path` to `baseURL`, preserving any existing
    /// `baseURL.path` so installations behind a sub-path still work.
    private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw GitLabAPIError.invalidBaseURL
        }
        let basePath = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        components.path = basePath + path
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw GitLabAPIError.invalidBaseURL }
        return url
    }

    /// Percent-encode the project identifier so paths like `group/sub/name` work.
    static func encode(_ id: String) -> String {
        if Int(id) != nil { return id }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        return id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // GitLab serialises timestamps with fractional seconds, e.g.
        // `2026-05-15T06:10:18.123Z`. The stock `.iso8601` strategy refuses
        // those, so decoding fails silently and the menu bar never receives
        // pipeline updates. Try the fractional variant first, fall back to the
        // plain ISO8601 form for older GitLab versions.
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = iso8601WithFractionalSeconds.date(from: raw) {
                return date
            }
            if let date = iso8601.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognised ISO8601 timestamp: \(raw)"
            )
        }
        return d
    }()
}

private let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let iso8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
