import XCTest
@testable import AdrianPortfolio

/// The content fallback chain: remote success → remote failure → cached copy → bundled copy.
final class PortfolioServiceTests: XCTestCase {
    private let remoteURL = URL(string: "https://example.com/portfolio.json")

    override func tearDown() {
        MockURLProtocol.setHandler(nil)
        super.tearDown()
    }

    // MARK: Builders

    private func makeService(
        remoteURL overrideURL: URL?? = nil,
        cache: InMemoryPortfolioCache = InMemoryPortfolioCache(),
        bundled: StubBundledContent? = nil
    ) throws -> LivePortfolioService {
        LivePortfolioService(
            remoteURL: overrideURL ?? remoteURL,
            apiClient: APIClient(session: MockURLProtocol.makeSession()),
            cache: cache,
            bundled: try bundled ?? .data(Fixture.data(headline: "BUNDLE"))
        )
    }

    // MARK: Remote success

    func testRemoteSuccessReturnsRemoteContentAndCachesIt() async throws {
        let remoteData = try Fixture.data(headline: "REMOTE")
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: remoteData))
        let cache = InMemoryPortfolioCache()

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .remote)
        XCTAssertEqual(content.portfolio.headline, "REMOTE")
        XCTAssertEqual(cache.storedData, remoteData)
        XCTAssertEqual(cache.writeCount, 1)
    }

    func testRemoteSuccessWinsOverExistingCache() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: try Fixture.data(headline: "REMOTE")))
        let cache = InMemoryPortfolioCache(data: try Fixture.data(headline: "CACHED"))

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.portfolio.headline, "REMOTE")
    }

    // MARK: Remote failure → cache

    func testOfflineFallsBackToCache() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))
        let cache = InMemoryPortfolioCache(data: try Fixture.data(headline: "CACHED"))

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .cache)
        XCTAssertEqual(content.portfolio.headline, "CACHED")
    }

    func testTimeoutFallsBackToCache() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.timedOut))
        let cache = InMemoryPortfolioCache(data: try Fixture.data(headline: "CACHED"))

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .cache)
    }

    func testHTTPErrorFallsBackToCache() async throws {
        for status in [404, 500, 503] {
            MockURLProtocol.setHandler(MockURLProtocol.respond(status: status, data: Data("nope".utf8)))
            let cache = InMemoryPortfolioCache(data: try Fixture.data(headline: "CACHED"))

            let content = try await makeService(cache: cache).load()

            XCTAssertEqual(content.source, .cache, "status \(status)")
        }
    }

    func testMalformedRemoteJSONFallsBackAndNeverOverwritesCache() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: Data("<html>oops</html>".utf8)))
        let cachedData = try Fixture.data(headline: "CACHED")
        let cache = InMemoryPortfolioCache(data: cachedData)

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .cache)
        XCTAssertEqual(cache.storedData, cachedData)
        XCTAssertEqual(cache.writeCount, 0)
    }

    func testEmptyButValidRemoteJSONIsRejected() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: Data("{}".utf8)))
        let cache = InMemoryPortfolioCache(data: try Fixture.data(headline: "CACHED"))

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .cache)
        XCTAssertEqual(content.portfolio.headline, "CACHED")
    }

    func testOversizedRemotePayloadFallsBack() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: Data(count: APIClient.maxPayloadBytes + 1)))
        let cache = InMemoryPortfolioCache(data: try Fixture.data(headline: "CACHED"))

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .cache)
    }

    // MARK: Remote failure, no cache → bundle

    func testOfflineWithNoCacheFallsBackToBundle() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))

        let content = try await makeService().load()

        XCTAssertEqual(content.source, .bundle)
        XCTAssertEqual(content.portfolio.headline, "BUNDLE")
    }

    func testCorruptCacheIsDiscardedAndBundleIsUsed() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))
        let cache = InMemoryPortfolioCache(data: Data("{{{ not json".utf8))

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .bundle)
        XCTAssertNil(cache.storedData)
        XCTAssertEqual(cache.clearCount, 1)
    }

    func testEmptyDocumentInCacheIsTreatedAsCorrupt() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))
        let cache = InMemoryPortfolioCache(data: Data("{}".utf8))

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .bundle)
        XCTAssertNil(cache.storedData)
    }

    // MARK: Total failure

    func testThrowsOnlyWhenEveryLayerFails() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))
        let service = try makeService(bundled: .missing)

        do {
            _ = try await service.load()
            XCTFail("Expected contentUnavailable")
        } catch {
            XCTAssertEqual(error as? AppError, .contentUnavailable)
        }
    }

    func testCorruptBundleWithNoOtherSourceThrows() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))
        let service = try makeService(bundled: .data(Data("garbage".utf8)))

        do {
            _ = try await service.load()
            XCTFail("Expected contentUnavailable")
        } catch {
            XCTAssertEqual(error as? AppError, .contentUnavailable)
        }
    }

    // MARK: The whole chain, in order

    func testFullChainInOrder() async throws {
        let cache = InMemoryPortfolioCache()
        let service = try makeService(cache: cache)

        // 1. Remote success.
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: try Fixture.data(headline: "REMOTE")))
        var content = try await service.load()
        XCTAssertEqual(content.source, .remote)
        XCTAssertEqual(content.portfolio.headline, "REMOTE")

        // 2. Remote failure → the copy cached in step 1.
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))
        content = try await service.load()
        XCTAssertEqual(content.source, .cache)
        XCTAssertEqual(content.portfolio.headline, "REMOTE")

        // 3. Cache gone (purged by the OS) → bundled copy.
        cache.clear()
        content = try await service.load()
        XCTAssertEqual(content.source, .bundle)
        XCTAssertEqual(content.portfolio.headline, "BUNDLE")

        // 4. Network returns → remote again, cache repopulated.
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: try Fixture.data(headline: "REMOTE 2")))
        content = try await service.load()
        XCTAssertEqual(content.source, .remote)
        XCTAssertEqual(content.portfolio.headline, "REMOTE 2")
        XCTAssertNotNil(cache.storedData)
    }

    // MARK: Edge cases

    func testNilRemoteURLSkipsTheNetwork() async throws {
        MockURLProtocol.setHandler { _ in
            XCTFail("Network must not be hit")
            throw URLError(.unknown)
        }
        let content = try await makeService(remoteURL: .some(nil)).load()
        XCTAssertEqual(content.source, .bundle)
    }

    func testCacheWriteFailureDoesNotDiscardFreshContent() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: try Fixture.data(headline: "REMOTE")))
        let cache = InMemoryPortfolioCache(failWrites: true)

        let content = try await makeService(cache: cache).load()

        XCTAssertEqual(content.source, .remote)
        XCTAssertEqual(content.portfolio.headline, "REMOTE")
    }

    // MARK: loadLocal

    func testLoadLocalPrefersCacheOverBundle() async throws {
        let cache = InMemoryPortfolioCache(data: try Fixture.data(headline: "CACHED"))
        let content = try await makeService(cache: cache).loadLocal()
        XCTAssertEqual(content.source, .cache)
    }

    func testLoadLocalNeverTouchesTheNetwork() async throws {
        MockURLProtocol.setHandler { _ in
            XCTFail("Network must not be hit")
            throw URLError(.unknown)
        }
        let content = try await makeService().loadLocal()
        XCTAssertEqual(content.source, .bundle)
    }

    // MARK: Bundle provider

    func testBundleContentProviderThrowsForMissingResource() {
        let provider = BundleContentProvider(bundle: Bundle(for: PortfolioServiceTests.self), resourceName: "does-not-exist")
        XCTAssertThrowsError(try provider.data())
    }
}

// MARK: - File cache

final class FilePortfolioCacheTests: XCTestCase {
    private var directory: URL = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testReadReturnsNilWhenNothingIsStored() {
        let cache = FilePortfolioCache(fileURL: directory.appendingPathComponent("c.json"))
        XCTAssertNil(cache.read())
    }

    func testWriteCreatesDirectoryAndRoundTrips() throws {
        let cache = FilePortfolioCache(fileURL: directory.appendingPathComponent("nested/c.json"))
        let data = try Fixture.data()
        try cache.write(data)
        XCTAssertEqual(cache.read(), data)
    }

    func testWriteReplacesPreviousContent() throws {
        let cache = FilePortfolioCache(fileURL: directory.appendingPathComponent("c.json"))
        try cache.write(Data("one".utf8))
        try cache.write(Data("two".utf8))
        XCTAssertEqual(cache.read(), Data("two".utf8))
    }

    func testClearRemovesTheFile() throws {
        let cache = FilePortfolioCache(fileURL: directory.appendingPathComponent("c.json"))
        try cache.write(Data("x".utf8))
        cache.clear()
        XCTAssertNil(cache.read())
        cache.clear() // clearing twice is harmless
    }

    func testStandardCacheLivesInACachesLocation() {
        let url = FilePortfolioCache.standard().fileURL
        XCTAssertEqual(url.lastPathComponent, "portfolio-cache.json")
    }
}
