import Foundation

/// The small, user-facing failure vocabulary for the whole app.
///
/// Messages are intentionally terse and free of technical detail.
enum AppError: Error, Equatable, Sendable {
    case offline
    case timeout
    case cancelled
    case badStatus(Int)
    case invalidResponse
    case payloadTooLarge
    /// The payload was received or read but is not a usable portfolio document.
    case invalidContent
    /// Neither the network, the cache, nor the bundled copy produced content.
    case contentUnavailable

    /// Normalizes any thrown error into an `AppError`.
    init(_ error: Error) {
        switch error {
        case let appError as AppError:
            self = appError
        case is CancellationError:
            self = .cancelled
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed:
                self = .offline
            case .timedOut:
                self = .timeout
            case .cancelled:
                self = .cancelled
            default:
                self = .invalidResponse
            }
        case is DecodingError:
            self = .invalidContent
        default:
            self = .invalidResponse
        }
    }

    /// Short, plain-language text that is safe to show to the user.
    var userMessage: String {
        switch self {
        case .offline: "You appear to be offline."
        case .timeout: "The request took too long."
        case .cancelled: "The request was cancelled."
        case .badStatus, .invalidResponse, .payloadTooLarge, .invalidContent:
            "The latest content isn't available right now."
        case .contentUnavailable: "Content is temporarily unavailable."
        }
    }
}

extension AppError: LocalizedError {
    var errorDescription: String? { userMessage }
}
