import XCTest
@testable import AdrianPortfolio

final class SafeURLTests: XCTestCase {

    // MARK: Web

    func testWebAcceptsHTTPAndHTTPS() {
        XCTAssertEqual(SafeURL.web(from: "https://github.com/Adrian93Box")?.absoluteString, "https://github.com/Adrian93Box")
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
        XCTAssertEqual(SafeURL.mail(from: "adrian93box@gmail.com")?.absoluteString, "mailto:adrian93box@gmail.com")
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
        XCTAssertEqual(SafeURL.phone(from: "850-363-3330")?.absoluteString, "tel:8503633330")
        XCTAssertEqual(SafeURL.phone(from: "(850) 363-3330")?.absoluteString, "tel:8503633330")
        XCTAssertEqual(SafeURL.phone(from: "+1 850 363 3330")?.absoluteString, "tel:+18503633330")
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
        let github = try XCTUnwrap(URL(string: "https://github.com/Adrian93Box"))
        XCTAssertEqual(github.displayString, "github.com/Adrian93Box")
    }
}

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

@MainActor
final class ContactViewModelTests: XCTestCase {
    private let contact = Contact(
        email: "a@example.com",
        phone: "850-363-3330",
        linkedIn: "https://www.linkedin.com/in/example",
        github: "https://github.com/example"
    )

    func testWebActionsPresentInAppBrowserWithoutOpeningExternally() {
        let viewModel = ContactViewModel()
        let opened = LockedBox<[URL]>([])

        viewModel.perform(.linkedIn, in: contact) { url, _ in opened.set(opened.value + [url]) }
        XCTAssertEqual(viewModel.webDestination?.url.absoluteString, "https://www.linkedin.com/in/example")

        viewModel.perform(.github, in: contact) { url, _ in opened.set(opened.value + [url]) }
        XCTAssertEqual(viewModel.webDestination?.url.absoluteString, "https://github.com/example")

        XCTAssertTrue(opened.value.isEmpty)
        XCTAssertNil(viewModel.alertMessage)
    }

    func testMailAndCallAreHandedToTheSystem() {
        let viewModel = ContactViewModel()
        let opened = LockedBox<[URL]>([])

        viewModel.perform(.email, in: contact) { url, completion in
            opened.set(opened.value + [url])
            completion(true)
        }
        viewModel.perform(.call, in: contact) { url, completion in
            opened.set(opened.value + [url])
            completion(true)
        }

        XCTAssertEqual(opened.value.map(\.absoluteString), ["mailto:a@example.com", "tel:8503633330"])
        XCTAssertNil(viewModel.alertMessage)
        XCTAssertNil(viewModel.webDestination)
    }

    func testSystemRefusalShowsATerseAlert() async {
        let viewModel = ContactViewModel()
        viewModel.perform(.call, in: contact) { _, completion in completion(false) }
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(viewModel.alertMessage, "Calling isn't available on this device.")

        viewModel.dismissAlert()
        XCTAssertNil(viewModel.alertMessage)
    }

    func testMissingValueShowsAlertInsteadOfCrashing() {
        let viewModel = ContactViewModel()
        for action in [ContactAction.email, .call, .linkedIn, .github] {
            viewModel.dismissAlert()
            viewModel.perform(action, in: Contact()) { _, _ in XCTFail("Nothing should open") }
            XCTAssertNotNil(viewModel.alertMessage, "\(action)")
        }
    }

    func testHostileLinksNeverReachTheBrowser() {
        let viewModel = ContactViewModel()
        let hostile = Contact(linkedIn: "javascript:alert(1)", github: "file:///etc/passwd")
        viewModel.perform(.linkedIn, in: hostile) { _, _ in }
        viewModel.perform(.github, in: hostile) { _, _ in }
        XCTAssertNil(viewModel.webDestination)
    }

    func testHasAnyAction() {
        XCTAssertFalse(Contact().hasAnyAction)
        XCTAssertTrue(Contact(phone: "850-363-3330").hasAnyAction)
        XCTAssertFalse(Contact(email: "nope", linkedIn: "javascript:1").hasAnyAction)
    }
}
