import XCTest
@testable import AdrianPortfolio

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
