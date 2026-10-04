import XCTest
@testable import AdrianPortfolio

final class APIClientTests: XCTestCase {
    private let url = URL(string: "https://example.com/portfolio.json")

    override func tearDown() {
        MockURLProtocol.setHandler(nil)
        super.tearDown()
    }

    private func makeClient() -> APIClient {
        APIClient(session: MockURLProtocol.makeSession())
    }

    private func fetch() async throws -> Data {
        guard let url else { throw AppError.invalidResponse }
        return try await makeClient().data(from: url)
    }

    private func assertFetchThrows(_ expected: AppError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await fetch()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? AppError, expected, file: file, line: line)
        }
    }

    func testReturnsBodyOnSuccess() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: Data("hello".utf8)))
        let data = try await fetch()
        XCTAssertEqual(data, Data("hello".utf8))
    }

    func testSendsJSONAcceptHeader() async throws {
        let seen = LockedBox<String?>(nil)
        MockURLProtocol.setHandler { request in
            seen.set(request.value(forHTTPHeaderField: "Accept"))
            return try MockURLProtocol.respond(data: Data())(request)
        }
        _ = try await fetch()
        XCTAssertEqual(seen.value, "application/json")
    }

    func testMapsBadStatus() async {
        MockURLProtocol.setHandler(MockURLProtocol.respond(status: 404, data: Data()))
        await assertFetchThrows(.badStatus(404))
        MockURLProtocol.setHandler(MockURLProtocol.respond(status: 500, data: Data()))
        await assertFetchThrows(.badStatus(500))
    }

    func testMapsOffline() async {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.notConnectedToInternet))
        await assertFetchThrows(.offline)
    }

    func testMapsTimeout() async {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.timedOut))
        await assertFetchThrows(.timeout)
    }

    func testMapsOtherURLErrorsToInvalidResponse() async {
        MockURLProtocol.setHandler(MockURLProtocol.fail(.badServerResponse))
        await assertFetchThrows(.invalidResponse)
    }

    func testRejectsOversizedPayload() async {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: Data(count: APIClient.maxPayloadBytes + 1)))
        await assertFetchThrows(.payloadTooLarge)
    }

    func testAcceptsPayloadAtTheLimit() async throws {
        MockURLProtocol.setHandler(MockURLProtocol.respond(data: Data(count: APIClient.maxPayloadBytes)))
        let data = try await fetch()
        XCTAssertEqual(data.count, APIClient.maxPayloadBytes)
    }

    // MARK: AppError

    func testAppErrorNormalizesForeignErrors() {
        XCTAssertEqual(AppError(CancellationError()), .cancelled)
        XCTAssertEqual(AppError(URLError(.cancelled)), .cancelled)
        XCTAssertEqual(AppError(URLError(.networkConnectionLost)), .offline)
        XCTAssertEqual(AppError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))), .invalidContent)
        XCTAssertEqual(AppError(CocoaError(.fileReadUnknown)), .invalidResponse)
        XCTAssertEqual(AppError(AppError.offline), .offline)
    }

    func testUserMessagesAreTerseAndFreeOfTechnicalDetail() {
        let all: [AppError] = [
            .offline, .timeout, .cancelled, .badStatus(500), .invalidResponse,
            .payloadTooLarge, .invalidContent, .contentUnavailable
        ]
        for error in all {
            let message = error.userMessage
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(message.contains("500"), "Status codes must not leak: \(message)")
            XCTAssertEqual(error.errorDescription, message)
        }
    }
}
