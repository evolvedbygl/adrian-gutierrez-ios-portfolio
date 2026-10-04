import Foundation
import os
import XCTest
@testable import AdrianPortfolio

// MARK: - Fixtures

private final class BundleToken {}

enum FixtureError: Error { case missing(String) }

enum Fixture {
    /// Raw bytes of a JSON fixture in the test bundle.
    static func data(_ name: String = "portfolio") throws -> Data {
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    static func portfolio() throws -> Portfolio {
        try PortfolioCoding.decode(try data())
    }

    /// The fixture re-encoded with a different headline, to tell "remote" apart
    /// from "cache" apart from "bundle" in assertions.
    static func data(headline: String) throws -> Data {
        var portfolio = try portfolio()
        portfolio.headline = headline
        return try JSONEncoder().encode(portfolio)
    }
}

// MARK: - Mock networking

/// Intercepts every request on sessions that list it in `protocolClasses`.
/// The handler lives behind a lock; XCTest runs tests serially, so one global slot is safe.
final class MockURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let handler = OSAllocatedUnfairLock<Handler?>(initialState: nil)

    static func setHandler(_ newHandler: Handler?) {
        handler.withLock { $0 = newHandler }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// A handler that always answers with `status` and `data`.
    static func respond(status: Int = 200, data: Data) -> Handler {
        { request in
            guard
                let url = request.url,
                let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else { throw URLError(.badURL) }
            return (response, data)
        }
    }

    /// A handler that always fails with `error`.
    static func fail(_ error: URLError.Code) -> Handler {
        { _ in throw URLError(error) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler.withLock({ $0 }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test doubles

final class InMemoryPortfolioCache: PortfolioCache {
    private struct State {
        var data: Data?
        var writeCount = 0
        var clearCount = 0
    }
    private let state: OSAllocatedUnfairLock<State>
    private let failWrites: Bool

    init(data: Data? = nil, failWrites: Bool = false) {
        self.state = OSAllocatedUnfairLock(initialState: State(data: data))
        self.failWrites = failWrites
    }

    var storedData: Data? { state.withLock { $0.data } }
    var writeCount: Int { state.withLock { $0.writeCount } }
    var clearCount: Int { state.withLock { $0.clearCount } }

    func read() -> Data? { storedData }

    func write(_ data: Data) throws {
        if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        state.withLock {
            $0.data = data
            $0.writeCount += 1
        }
    }

    func clear() {
        state.withLock {
            $0.data = nil
            $0.clearCount += 1
        }
    }
}

struct StubBundledContent: BundledContentProvider {
    let result: Result<Data, AppError>

    static func data(_ data: Data) -> StubBundledContent { StubBundledContent(result: .success(data)) }
    static let missing = StubBundledContent(result: .failure(.contentUnavailable))

    func data() throws -> Data { try result.get() }
}

// MARK: - Helpers

extension PortfolioContent {
    static func stub(headline: String = "Stub", source: ContentSource = .remote) -> PortfolioContent {
        PortfolioContent(
            portfolio: Portfolio(name: "Stub Person", headline: headline, about: ["About"]),
            source: source
        )
    }
}

/// A tiny thread-safe value holder for capturing values from `@Sendable` closures.
final class LockedBox<Value: Sendable>: Sendable {
    private let lock: OSAllocatedUnfairLock<Value>

    init(_ value: Value) {
        lock = OSAllocatedUnfairLock(initialState: value)
    }

    var value: Value { lock.withLock { $0 } }

    func set(_ newValue: Value) {
        lock.withLock { $0 = newValue }
    }
}
