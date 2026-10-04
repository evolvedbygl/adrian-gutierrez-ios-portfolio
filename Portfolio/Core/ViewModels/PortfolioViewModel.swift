import Foundation
import Observation

/// Owns the portfolio's load state. Views read it; the service does the I/O.
///
/// Launch sequence: show the best local copy immediately (cache, else bundle),
/// then refresh from the network in the background and swap in fresh content.
@MainActor
@Observable
final class PortfolioViewModel {
    enum State: Equatable {
        case loading
        case loaded(PortfolioContent)
        case failed(AppError)
    }

    private(set) var state: State
    private(set) var isRefreshing = false

    private let service: any PortfolioService
    private var hasStarted = false

    init(service: any PortfolioService, initialState: State = .loading) {
        self.service = service
        self.state = initialState
        self.hasStarted = initialState != .loading
    }

    // MARK: Derived state for views

    var portfolio: Portfolio? {
        if case let .loaded(content) = state { return content.portfolio }
        return nil
    }

    /// `true` when the visible content is a cached or bundled fallback and no
    /// refresh is in flight (so the indicator doesn't flash during launch).
    var isShowingOfflineContent: Bool {
        if case let .loaded(content) = state { return content.source.isFallback && !isRefreshing }
        return false
    }

    // MARK: Intents

    /// Loads local content, then refreshes. Safe to call repeatedly; only the first call acts.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await loadLocal()
        await refresh()
    }

    /// Re-fetches content. Pull-to-refresh calls this. Never surfaces a
    /// connectivity error; on failure the current content simply stays.
    func refresh() async {
        // Run unstructured so SwiftUI cancelling the `.refreshable` task (which it
        // does when the view hierarchy updates mid-refresh) can't abort the fetch.
        await Task { await self.performRefresh() }.value
    }

    /// Recovery from the `.failed` state.
    func retry() async {
        hasStarted = false
        state = .loading
        await start()
    }

    // MARK: Private

    private func loadLocal() async {
        do {
            state = .loaded(try await service.loadLocal())
        } catch {
            state = .failed(AppError(error))
        }
    }

    private func performRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            state = .loaded(try await service.load())
        } catch {
            // Keep whatever we are already showing; only an empty app reports a failure.
            if case .loaded = state { return }
            state = .failed(AppError(error))
        }
    }
}

extension PortfolioViewModel {
    /// A ready-to-render view model for SwiftUI previews.
    static func preview(
        _ portfolio: Portfolio = .sample,
        source: ContentSource = .remote
    ) -> PortfolioViewModel {
        PortfolioViewModel(
            service: MockPortfolioService.online(portfolio),
            initialState: .loaded(PortfolioContent(portfolio: portfolio, source: source))
        )
    }

    static func previewLoading() -> PortfolioViewModel {
        PortfolioViewModel(service: MockPortfolioService.online(), initialState: .loading)
    }

    static func previewFailed() -> PortfolioViewModel {
        PortfolioViewModel(service: MockPortfolioService.failing(), initialState: .failed(.contentUnavailable))
    }
}
