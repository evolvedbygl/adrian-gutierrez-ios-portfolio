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
        XCTAssertNotNil(PortfolioViewModel.preview().portfolio)
    }
}
