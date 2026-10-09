import SwiftUI
import XCTest
@testable import AdrianPortfolio

@MainActor
final class PortfolioViewModelTests: XCTestCase {

    func testStartsInLoadingState() {
        let viewModel = PortfolioViewModel(service: MockPortfolioService.online())
        XCTAssertEqual(viewModel.state, .loading)
        XCTAssertNil(viewModel.portfolio)
        XCTAssertFalse(viewModel.isShowingOfflineContent)
    }

    func testStartShowsRemoteContentWhenOnline() async {
        let service = MockPortfolioService(
            local: .success(.stub(headline: "LOCAL", source: .bundle)),
            remote: .success(.stub(headline: "REMOTE", source: .remote))
        )
        let viewModel = PortfolioViewModel(service: service)

        await viewModel.start()

        XCTAssertEqual(viewModel.portfolio?.headline, "REMOTE")
        XCTAssertFalse(viewModel.isShowingOfflineContent)
        XCTAssertFalse(viewModel.isRefreshing)
        let localCalls = await service.loadLocalCallCount
        let remoteCalls = await service.loadCallCount
        XCTAssertEqual(localCalls, 1)
        XCTAssertEqual(remoteCalls, 1)
    }

    func testStartShowsLocalContentBeforeTheNetworkAnswers() async throws {
        let service = MockPortfolioService.online(Portfolio(name: "P", headline: "H", about: ["A"]), delay: .milliseconds(300))
        let viewModel = PortfolioViewModel(service: service)

        let task = Task { await viewModel.start() }
        try await Task.sleep(for: .milliseconds(100))

        // Local content is on screen while the refresh is still in flight.
        XCTAssertNotNil(viewModel.portfolio)
        XCTAssertTrue(viewModel.isRefreshing)
        // …and the offline pill is suppressed during that window.
        XCTAssertFalse(viewModel.isShowingOfflineContent)

        await task.value
        XCTAssertFalse(viewModel.isRefreshing)
    }

    func testOfflineIndicatorShowsForFallbackContent() async {
        for source in [ContentSource.cache, .bundle] {
            let content = PortfolioContent.stub(source: source)
            let viewModel = PortfolioViewModel(
                service: MockPortfolioService(local: .success(content), remote: .success(content))
            )
            await viewModel.start()
            XCTAssertTrue(viewModel.isShowingOfflineContent, "\(source)")
        }
    }

    func testFailureStateWhenNothingIsAvailable() async {
        let viewModel = PortfolioViewModel(service: MockPortfolioService.failing())
        await viewModel.start()
        XCTAssertEqual(viewModel.state, .failed(.contentUnavailable))
        XCTAssertNil(viewModel.portfolio)
        XCTAssertFalse(viewModel.isShowingOfflineContent)
    }

    func testRefreshFailureKeepsExistingContent() async {
        let service = MockPortfolioService(
            local: .success(.stub(headline: "LOCAL", source: .bundle)),
            remote: .failure(.offline)
        )
        let viewModel = PortfolioViewModel(service: service)

        await viewModel.start()

        XCTAssertEqual(viewModel.portfolio?.headline, "LOCAL")
        if case .failed = viewModel.state { XCTFail("A connectivity failure must never become an error screen") }
    }

    func testPullToRefreshSwapsInFreshContent() async {
        let service = MockPortfolioService(
            local: .success(.stub(headline: "LOCAL", source: .bundle)),
            remote: .failure(.offline)
        )
        let viewModel = PortfolioViewModel(service: service)
        await viewModel.start()
        XCTAssertEqual(viewModel.portfolio?.headline, "LOCAL")

        await service.setRemoteResult(.success(.stub(headline: "FRESH", source: .remote)))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.portfolio?.headline, "FRESH")
        XCTAssertFalse(viewModel.isShowingOfflineContent)
    }

    func testStartIsIdempotent() async {
        let service = MockPortfolioService.online()
        let viewModel = PortfolioViewModel(service: service)

        await viewModel.start()
        await viewModel.start()

        let localCalls = await service.loadLocalCallCount
        XCTAssertEqual(localCalls, 1)
    }

    func testRetryRecoversFromFailure() async {
        let service = MockPortfolioService.failing()
        let viewModel = PortfolioViewModel(service: service)
        await viewModel.start()
        XCTAssertEqual(viewModel.state, .failed(.contentUnavailable))

        await service.setLocalResult(.success(.stub(headline: "BACK", source: .bundle)))
        await service.setRemoteResult(.success(.stub(headline: "BACK", source: .remote)))
        await viewModel.retry()

        XCTAssertEqual(viewModel.portfolio?.headline, "BACK")
    }

    func testPreviewHelpersProduceExpectedStates() {
        XCTAssertEqual(PortfolioViewModel.previewLoading().state, .loading)
        XCTAssertEqual(PortfolioViewModel.previewFailed().state, .failed(.contentUnavailable))
        XCTAssertNil(PortfolioViewModel.previewLoading().portfolio)
        XCTAssertNil(PortfolioViewModel.previewFailed().portfolio)
        XCTAssertNotNil(PortfolioViewModel.preview().portfolio)
    }

    private func renderView<V: View>(_ view: V) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hosting = UIHostingController(rootView: view)
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
    }

    func testViewRenderingAcrossAllTabsAndStates() {
        let loadedVM = PortfolioViewModel.preview()
        let loadingVM = PortfolioViewModel.previewLoading()
        let failedVM = PortfolioViewModel.previewFailed()
        let emptyPortfolio = Portfolio(name: "", headline: "iOS Engineer", about: ["Brief"])
        let emptyVM = PortfolioViewModel.preview(emptyPortfolio)

        // RootView across tabs
        for tab in AppTab.allCases {
            renderView(RootView(viewModel: loadedVM, initialTab: tab))
        }

        // AboutView
        renderView(AboutView(viewModel: loadedVM))
        renderView(AboutView(viewModel: loadingVM))
        renderView(AboutView(viewModel: failedVM))
        renderView(AboutView(viewModel: emptyVM))
        renderView(PortraitView(name: "Adrian Gutierrez", initials: "AG"))
        renderView(PortraitView(name: "", initials: ""))
        renderView(AvailabilityBadge(text: "Open to iOS roles"))

        // ExperienceView & TimelineRow
        renderView(ExperienceView(viewModel: loadedVM))
        renderView(ExperienceView(viewModel: loadingVM))
        renderView(ExperienceView(viewModel: failedVM))
        renderView(ExperienceView(viewModel: emptyVM))
        let sampleExperience = loadedVM.portfolio?.experience.first ?? Experience(title: "iOS Engineer", company: "Company", startDate: "2021-10")
        renderView(TimelineRow(experience: sampleExperience, isLast: false))
        renderView(TimelineRow(experience: sampleExperience, isLast: true))
        let minimalExperience = Experience(title: "", company: "", detail: "", summary: "", startDate: nil, endDate: nil, bullets: [])
        renderView(TimelineRow(experience: minimalExperience, isLast: true))

        // WorkView, ProjectCard, CapabilityGroupView
        renderView(WorkView(viewModel: loadedVM))
        renderView(WorkView(viewModel: loadingVM))
        renderView(WorkView(viewModel: failedVM))
        renderView(WorkView(viewModel: emptyVM))
        let sampleProject = loadedVM.portfolio?.projects.first ?? Project(name: "My Business", description: "Desc", status: "Live", linkLabel: "Learn more", linkURL: "https://example.com")
        renderView(ProjectCard(project: sampleProject) { _ in })
        let minimalProject = Project(name: "Test", description: "", status: "", linkLabel: "", linkURL: "")
        renderView(ProjectCard(project: minimalProject) { _ in })
        let sampleCapability = loadedVM.portfolio?.capabilityGroups.first ?? CapabilityGroup(title: "Group", items: ["Item 1", "Item 2"])
        renderView(CapabilityGroupView(group: sampleCapability))

        // ContactView, ContactButton, ShareLink
        renderView(ContactView(viewModel: loadedVM))
        renderView(ContactView(viewModel: loadingVM))
        renderView(ContactView(viewModel: failedVM))
        renderView(ContactView(viewModel: emptyVM))
        renderView(ContactButton(title: "Email", detail: "test@example.com", systemImage: "envelope", accessibilityHint: "Opens Mail") {})
        renderView(ContactButton(title: "GitHub", detail: "github.com", systemImage: "chevron.left", trailingImage: "arrow.up.right", accessibilityHint: "Opens GitHub") {})
        renderView(ContactButton(title: "Action", detail: nil, systemImage: "star", accessibilityHint: "Action") {})

        // Shared Components & SafariView
        renderView(EmptySectionView(title: "Empty", message: "No items", systemImage: "tray"))
        renderView(Text("Test").offlineIndicator(true))
        renderView(Text("Test").offlineIndicator(false))
        renderView(SectionHeader(title: "Header"))
        let safari = SafariView(url: URL(string: "https://evolvedbygl.com")!)
        renderView(safari)
    }
}

