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

    init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    // MARK: - GitLabAPI

    func recentPipelines(projectID: String, perPage: Int = AppConstants.Default.perPage) async throws -> [Pipeline] {
        let encoded = Self.encode(projectID)
        let path = String(format: AppConstants.API.pipelinesPath, encoded)
        let url = try makeURL(path: path, query: [
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "order_by", value: "updated_at"),
            URLQueryItem(name: "sort", value: "desc"),
        ])
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
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
