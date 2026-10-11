import XCTest
@testable import AdrianPortfolio

@MainActor
final class ContactViewModelTests: XCTestCase {
    private let contact = Contact(
        email: "a@example.com",
        phone: "850-370-4979",
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

        XCTAssertEqual(opened.value.map(\.absoluteString), ["mailto:a@example.com", "tel:8503704979"])
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
        XCTAssertTrue(Contact(phone: "850-370-4979").hasAnyAction)
        XCTAssertFalse(Contact(email: "nope", linkedIn: "javascript:1").hasAnyAction)
    }
}
