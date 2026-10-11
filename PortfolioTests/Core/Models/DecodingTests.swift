import XCTest
@testable import AdrianPortfolio

final class DecodingTests: XCTestCase {

    // MARK: Fixture

    func testFixtureDecodesEveryField() throws {
        let portfolio = try Fixture.portfolio()

        XCTAssertEqual(portfolio.name, "Test Person")
        XCTAssertEqual(portfolio.headline, "Fixture Engineer")
        XCTAssertEqual(portfolio.availability, "Open to testing")
        XCTAssertEqual(portfolio.about.count, 2)
        XCTAssertEqual(portfolio.experience.count, 3)
        XCTAssertEqual(portfolio.experience[0].company, "Example Co")
        XCTAssertEqual(portfolio.experience[0].startDate, "2021-10")
        XCTAssertEqual(portfolio.experience[0].endDate, "2026-06")
        XCTAssertEqual(portfolio.experience[0].bullets.count, 2)
        XCTAssertEqual(portfolio.projects.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(portfolio.capabilityGroups.first?.items, ["Swift & SwiftUI", "WidgetKit"])
        XCTAssertEqual(portfolio.beforeSoftware, ["A short origin story."])
        XCTAssertEqual(portfolio.contact.email, "person@example.com")
        XCTAssertEqual(portfolio.contact.website, "https://example.com/person")
    }

    func testUnknownFieldsAreIgnored() throws {
        // The fixture contains "someFutureField"; decoding it must not throw.
        XCTAssertNoThrow(try Fixture.portfolio())
    }

    func testRoundTripPreservesContent() throws {
        let original = try Fixture.portfolio()
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Portfolio.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: Missing fields

    func testEmptyObjectDecodesToDefaultsButIsNotRenderable() throws {
        let portfolio = try JSONDecoder().decode(Portfolio.self, from: Data("{}".utf8))
        XCTAssertEqual(portfolio, Portfolio())
        XCTAssertFalse(portfolio.isRenderable)
    }

    func testPartialDocumentFillsDefaults() throws {
        let json = #"{"headline": "iOS Engineer", "about": ["Hi"], "experience": [{"title": "Dev"}]}"#
        let portfolio = try PortfolioCoding.decode(Data(json.utf8))

        XCTAssertEqual(portfolio.headline, "iOS Engineer")
        XCTAssertEqual(portfolio.tagline, "")
        XCTAssertEqual(portfolio.experience.first?.title, "Dev")
        XCTAssertNil(portfolio.experience.first?.startDate)
        XCTAssertEqual(portfolio.experience.first?.bullets, [])
        XCTAssertEqual(portfolio.projects, [])
        XCTAssertEqual(portfolio.contact, Contact())
    }

    func testNullValuesFallBackToDefaults() throws {
        let json = #"{"headline": "iOS Engineer", "about": ["Hi"], "tagline": null, "contact": null, "projects": null}"#
        let portfolio = try PortfolioCoding.decode(Data(json.utf8))
        XCTAssertEqual(portfolio.tagline, "")
        XCTAssertEqual(portfolio.projects, [])
        XCTAssertEqual(portfolio.contact, Contact())
    }

    // MARK: Validation

    func testCodingRejectsMalformedJSON() {
        XCTAssertThrowsError(try PortfolioCoding.decode(Data("not json".utf8))) {
            XCTAssertEqual($0 as? AppError, .invalidContent)
        }
        XCTAssertThrowsError(try PortfolioCoding.decode(Data("<html>404</html>".utf8)))
        XCTAssertThrowsError(try PortfolioCoding.decode(Data()))
    }

    func testCodingRejectsWrongTypes() {
        XCTAssertThrowsError(try PortfolioCoding.decode(Data(#"{"headline": 42}"#.utf8)))
        XCTAssertThrowsError(try PortfolioCoding.decode(Data(#"["array", "root"]"#.utf8)))
    }

    func testCodingRejectsDocumentsWithNothingToShow() {
        XCTAssertThrowsError(try PortfolioCoding.decode(Data("{}".utf8))) {
            XCTAssertEqual($0 as? AppError, .invalidContent)
        }
        // Identity but no body.
        XCTAssertThrowsError(try PortfolioCoding.decode(Data(#"{"headline": "iOS Engineer"}"#.utf8)))
    }

    // MARK: Derived values

    func testNameDerivedValues() {
        let portfolio = Portfolio(name: "Adrian Gutierrez")
        XCTAssertEqual(portfolio.firstName, "Adrian")
        XCTAssertEqual(portfolio.initials, "AG")
        XCTAssertEqual(Portfolio().firstName, "")
        XCTAssertEqual(Portfolio().initials, "")
        XCTAssertEqual(Portfolio(name: "Cher").initials, "C")
    }

    // MARK: Dates

    func testYearMonthParsing() {
        XCTAssertEqual(YearMonth(string: "2021-10"), YearMonth(year: 2021, month: 10))
        XCTAssertNil(YearMonth(string: "2021-13"))
        XCTAssertNil(YearMonth(string: "2021"))
        XCTAssertNil(YearMonth(string: "21-10"))
        XCTAssertNil(YearMonth(string: "soon"))
        XCTAssertNil(YearMonth(string: ""))
        let earlier = YearMonth(string: "2020-12")
        let later = YearMonth(string: "2021-01")
        XCTAssertNotNil(earlier)
        XCTAssertNotNil(later)
        XCTAssertEqual(earlier.flatMap { e in later.map { e < $0 } }, true)
    }

    func testDateRangeText() {
        let en = Locale(identifier: "en_US")
        XCTAssertEqual(DateRangeFormatter.text(start: "2021-10", end: "2026-06", locale: en), "Oct 2021 – Jun 2026")
        XCTAssertEqual(DateRangeFormatter.text(start: "2026-06", end: nil, locale: en), "Jun 2026 – Present")
        XCTAssertEqual(DateRangeFormatter.text(start: nil, end: "2020-12", locale: en), "Dec 2020")
        XCTAssertEqual(DateRangeFormatter.text(start: "2020-12", end: "2020-12", locale: en), "Dec 2020")
        XCTAssertEqual(DateRangeFormatter.text(start: nil, end: nil, locale: en), "")
        XCTAssertEqual(DateRangeFormatter.text(start: "", end: "  ", locale: en), "")
    }

    func testUnparseableDateIsShownAsWritten() {
        let en = Locale(identifier: "en_US")
        XCTAssertEqual(DateRangeFormatter.text(start: "Spring 2019", end: "2020-12", locale: en), "Spring 2019 – Dec 2020")
    }

    // MARK: Bundled content

    func testBundledPortfolioDecodesAndMatchesTheBrief() throws {
        let provider = BundleContentProvider(bundle: Bundle(for: PortfolioViewModel.self))
        let portfolio = try PortfolioCoding.decode(try provider.data())

        XCTAssertEqual(portfolio.headline, "iOS Engineer")
        XCTAssertEqual(portfolio.availability, "Open to iOS roles")
        XCTAssertEqual(portfolio.experience.count, 3)
        XCTAssertEqual(portfolio.experience[0].company, "Open Path Products LLC")
        XCTAssertEqual(portfolio.experience[0].startDate, "2021-10")
        XCTAssertEqual(portfolio.experience[0].endDate, "2026-06")
        XCTAssertEqual(portfolio.experience[0].bullets.count, 4)
        XCTAssertEqual(portfolio.experience[1].company, "Gold Life LLC")
        XCTAssertNil(portfolio.experience[1].endDate)
        XCTAssertEqual(portfolio.experience[2].company, "Full Sail University")
        XCTAssertEqual(portfolio.projects.count, 3)
        XCTAssertFalse(portfolio.capabilityGroups.isEmpty)
        XCTAssertFalse(portfolio.beforeSoftware.isEmpty)
    }

    func testBundledContactActionsAllResolve() throws {
        let provider = BundleContentProvider(bundle: Bundle(for: PortfolioViewModel.self))
        let contact = try PortfolioCoding.decode(try provider.data()).contact

        XCTAssertEqual(contact.mailURL?.absoluteString, "mailto:software@evolvedbygl.com")
        XCTAssertEqual(contact.phoneURL?.absoluteString, "tel:8503633330")
        XCTAssertEqual(contact.linkedInURL?.absoluteString, "https://www.linkedin.com/in/adrian93gutierrez")
        XCTAssertEqual(contact.githubURL?.absoluteString, "https://github.com/Adrian93Box")
        XCTAssertEqual(contact.websiteURL?.absoluteString, "https://evolvedbygl.com/adrian")
    }

    func testBundledProjectLinksAreSafeWebURLs() throws {
        let provider = BundleContentProvider(bundle: Bundle(for: PortfolioViewModel.self))
        let portfolio = try PortfolioCoding.decode(try provider.data())
        for project in portfolio.projects {
            XCTAssertNotNil(project.link, "\(project.name) has no valid link")
        }
    }
}
