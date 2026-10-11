import XCTest
@testable import AdrianPortfolio

final class SafeURLTests: XCTestCase {

    // MARK: Web

    func testWebAcceptsHTTPAndHTTPS() {
        XCTAssertEqual(SafeURL.web(from: "https://github.com/evolvedbygl")?.absoluteString, "https://github.com/evolvedbygl")
        XCTAssertNotNil(SafeURL.web(from: "http://example.com"))
        XCTAssertNotNil(SafeURL.web(from: "  https://example.com/path  "))
        XCTAssertNotNil(SafeURL.web(from: "HTTPS://EXAMPLE.COM"))
    }

    func testWebRejectsEverythingElse() {
        for bad in ["", "   ", "javascript:alert(1)", "file:///etc/passwd", "tel:5551234", "mailto:a@b.co",
                    "ftp://example.com", "portfolio://contact", "example.com", "https://", "https:///nohost", "not a url"] {
            XCTAssertNil(SafeURL.web(from: bad), "should reject \(bad)")
        }
    }

    // MARK: Mail

    func testMailBuildsMailtoURL() {
        XCTAssertEqual(SafeURL.mail(from: "software@evolvedbygl.com")?.absoluteString, "mailto:software@evolvedbygl.com")
        XCTAssertEqual(SafeURL.mail(from: " a.b+tag@example.co.uk ")?.scheme, "mailto")
    }

    func testMailRejectsMalformedAndInjectionAttempts() {
        for bad in ["", "plain", "@example.com", "a@", "a@b", "a@@b.co", "a@b.co?cc=x@y.com", "a@b.co&bcc=x@y.com",
                    "a@b.co,c@d.co", "a@b.co;c@d.co", "a b@c.co", "a@b.co\nBcc: x@y.co", "<a@b.co>", "a%40b@c.co"] {
            XCTAssertNil(SafeURL.mail(from: bad), "should reject \(bad.debugDescription)")
        }
    }

    // MARK: Phone

    func testPhoneKeepsDigitsOnly() {
        XCTAssertEqual(SafeURL.phone(from: "850-370-4979")?.absoluteString, "tel:8503704979")
        XCTAssertEqual(SafeURL.phone(from: "(850) 370-4979")?.absoluteString, "tel:8503704979")
        XCTAssertEqual(SafeURL.phone(from: "+1 850 370 4979")?.absoluteString, "tel:+18503704979")
    }

    func testPhoneRejectsImplausibleNumbers() {
        for bad in ["", "abc", "123", "1234567890123456", "   "] {
            XCTAssertNil(SafeURL.phone(from: bad), "should reject \(bad)")
        }
    }

    // MARK: Display

    func testDisplayStringStripsSchemeWwwAndTrailingSlash() throws {
        let linkedIn = try XCTUnwrap(URL(string: "https://www.linkedin.com/in/adrian93gutierrez/"))
        XCTAssertEqual(linkedIn.displayString, "linkedin.com/in/adrian93gutierrez")
        let github = try XCTUnwrap(URL(string: "https://github.com/evolvedbygl"))
        XCTAssertEqual(github.displayString, "github.com/evolvedbygl")
    }
}
