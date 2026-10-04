import Foundation
import OSLog

// MARK: - Content types

/// Where a piece of content came from.
enum ContentSource: Equatable, Sendable {
    case remote
    case cache
    case bundle

    /// `true` for anything other than a fresh remote fetch.
    var isFallback: Bool { self != .remote }
}

/// A decoded portfolio plus its provenance.
struct PortfolioContent: Equatable, Sendable {
    let portfolio: Portfolio
    let source: ContentSource
}

// MARK: - Decoding

enum PortfolioCoding {
    /// Decodes and validates a content document. Throws ``AppError/invalidContent``
    /// for malformed JSON *and* for well-formed JSON with nothing to show.
    static func decode(_ data: Data) throws -> Portfolio {
        let portfolio: Portfolio
        do {
            portfolio = try JSONDecoder().decode(Portfolio.self, from: data)
        } catch {
            throw AppError.invalidContent
        }
        guard portfolio.isRenderable else { throw AppError.invalidContent }
        return portfolio
    }
}

// MARK: - Service protocol

/// The single source of portfolio content for the app.
protocol PortfolioService: Sendable {
    /// Fast, offline path: the cached remote copy if valid, otherwise the bundled copy.
    /// Throws ``AppError/contentUnavailable`` only if both are unusable.
    func loadLocal() async throws -> PortfolioContent

    /// Full chain: remote → cache → bundle. A remote failure of any kind is
    /// absorbed and the best local copy is returned instead.
    func load() async throws -> PortfolioContent
}

// MARK: - Bundled content

/// Supplies the bundled fallback document. A protocol so tests can simulate a
/// missing or corrupt bundle.
protocol BundledContentProvider: Sendable {
    func data() throws -> Data
}

struct BundleContentProvider: BundledContentProvider {
    private let bundle: Bundle
    private let resourceName: String

    init(bundle: Bundle, resourceName: String = "portfolio") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func data() throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw AppError.contentUnavailable
        }
        return try Data(contentsOf: url)
    }
}

// MARK: - Live implementation

/// Remote → cache → bundle.
///
/// * A remote document is cached only after it decodes *and* validates, so the
///   cache never holds bad data.
/// * A cached document is re-validated on read; a corrupt one is deleted.
/// * Every failure in the remote step is silent by design: the user always sees
///   content, never an error screen for connectivity problems.
struct LivePortfolioService: PortfolioService {
    private let remoteURL: URL?
    private let apiClient: any APIClientProtocol
    private let cache: any PortfolioCache
    private let bundled: any BundledContentProvider
    private let logger = Logger(subsystem: "com.evolvedbygl.portfolio", category: "content")

    /// - Parameter remoteURL: `nil` disables the remote step (always local content).
    init(
        remoteURL: URL?,
        apiClient: any APIClientProtocol,
        cache: any PortfolioCache,
        bundled: any BundledContentProvider
    ) {
        self.remoteURL = remoteURL
        self.apiClient = apiClient
        self.cache = cache
        self.bundled = bundled
    }

    func load() async throws -> PortfolioContent {
        if let remote = await loadRemote() {
            return remote
        }
        return try await loadLocal()
    }

    func loadLocal() async throws -> PortfolioContent {
        if let cached = loadCached() {
            return cached
        }
        do {
            let portfolio = try PortfolioCoding.decode(try bundled.data())
            return PortfolioContent(portfolio: portfolio, source: .bundle)
        } catch {
            logger.error("Bundled content unusable")
            throw AppError.contentUnavailable
        }
    }

    // MARK: Steps

    private func loadRemote() async -> PortfolioContent? {
        guard let remoteURL else { return nil }
        do {
            let data = try await apiClient.data(from: remoteURL)
            let portfolio = try PortfolioCoding.decode(data)
            do {
                try cache.write(data)
            } catch {
                // A failed cache write must not discard good fresh content.
                logger.error("Could not write content cache")
            }
            return PortfolioContent(portfolio: portfolio, source: .remote)
        } catch {
            logger.info("Remote content unavailable, using local copy")
            return nil
        }
    }

    private func loadCached() -> PortfolioContent? {
        guard let data = cache.read() else { return nil }
        do {
            return PortfolioContent(portfolio: try PortfolioCoding.decode(data), source: .cache)
        } catch {
            logger.error("Discarding corrupt content cache")
            cache.clear()
            return nil
        }
    }
}

// MARK: - Mock (previews and tests)

/// A scriptable service that powers SwiftUI previews and unit tests.
actor MockPortfolioService: PortfolioService {
    private var localResult: Result<PortfolioContent, AppError>
    private var remoteResult: Result<PortfolioContent, AppError>
    private let delay: Duration

    private(set) var loadLocalCallCount = 0
    private(set) var loadCallCount = 0

    init(
        local: Result<PortfolioContent, AppError>,
        remote: Result<PortfolioContent, AppError>,
        delay: Duration = .zero
    ) {
        self.localResult = local
        self.remoteResult = remote
        self.delay = delay
    }

    /// Both steps succeed; `load()` returns fresh remote content.
    static func online(_ portfolio: Portfolio = .sample, delay: Duration = .zero) -> MockPortfolioService {
        MockPortfolioService(
            local: .success(PortfolioContent(portfolio: portfolio, source: .bundle)),
            remote: .success(PortfolioContent(portfolio: portfolio, source: .remote)),
            delay: delay
        )
    }

    /// The network is down; both steps return the bundled copy.
    static func offline(_ portfolio: Portfolio = .sample) -> MockPortfolioService {
        let content = PortfolioContent(portfolio: portfolio, source: .bundle)
        return MockPortfolioService(local: .success(content), remote: .success(content))
    }

    /// Nothing is available at all.
    static func failing(_ error: AppError = .contentUnavailable) -> MockPortfolioService {
        MockPortfolioService(local: .failure(error), remote: .failure(error))
    }

    func setRemoteResult(_ result: Result<PortfolioContent, AppError>) {
        remoteResult = result
    }

    func setLocalResult(_ result: Result<PortfolioContent, AppError>) {
        localResult = result
    }

    func loadLocal() async throws -> PortfolioContent {
        loadLocalCallCount += 1
        return try localResult.get()
    }

    func load() async throws -> PortfolioContent {
        loadCallCount += 1
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return try remoteResult.get()
    }
}
