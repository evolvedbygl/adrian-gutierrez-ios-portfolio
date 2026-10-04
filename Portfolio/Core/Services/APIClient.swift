import Foundation

/// Minimal networking seam so the service layer can be tested without a network.
protocol APIClientProtocol: Sendable {
    /// Fetches the body at `url`. Always throws an ``AppError``.
    func data(from url: URL) async throws -> Data
}

/// The app's single HTTP client: `URLSession` + async/await, failures mapped to ``AppError``.
struct APIClient: APIClientProtocol {
    /// Upper bound for a content document. The real file is a few KB; this just
    /// stops a misbehaving host from filling the cache.
    static let maxPayloadBytes = 1_000_000
    static let requestTimeout: TimeInterval = 10

    private let session: URLSession

    /// The session is injected (tests pass one backed by a mock `URLProtocol`);
    /// there is no shared client.
    init(session: URLSession) {
        self.session = session
    }

    /// A private session with no cookies and no persistent URL cache. The service
    /// layer owns caching explicitly, so there is exactly one copy of the truth.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout * 2
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.requestTimeout
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AppError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppError.badStatus(http.statusCode) }
        guard data.count <= Self.maxPayloadBytes else { throw AppError.payloadTooLarge }
        return data
    }
}
