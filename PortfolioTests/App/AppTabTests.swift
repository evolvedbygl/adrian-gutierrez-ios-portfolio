import XCTest
@testable import AdrianPortfolio

final class AppTabTests: XCTestCase {
    func testDeepLinkRoundTripsForEveryTab() throws {
        for tab in AppTab.allCases {
            let url = try XCTUnwrap(tab.deepLinkURL)
            XCTAssertEqual(url.absoluteString, "portfolio://\(tab.rawValue)")
            XCTAssertEqual(AppTab(deepLink: url), tab)
        }
    }

    func testParsingIsCaseInsensitiveAndStrict() throws {
        XCTAssertEqual(AppTab(deepLink: try XCTUnwrap(URL(string: "PORTFOLIO://Contact"))), .contact)
        XCTAssertNil(AppTab(deepLink: try XCTUnwrap(URL(string: "portfolio://settings"))))
        XCTAssertNil(AppTab(deepLink: try XCTUnwrap(URL(string: "https://contact"))))
        XCTAssertNil(AppTab(deepLink: try XCTUnwrap(URL(string: "portfolio:contact"))))
    }
}
