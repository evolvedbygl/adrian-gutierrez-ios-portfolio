import Foundation

/// Persistence for the last good remote document.
protocol PortfolioCache: Sendable {
    /// The raw cached bytes, or `nil` when nothing usable is stored.
    func read() -> Data?
    func write(_ data: Data) throws
    func clear()
}

/// Stores the last good remote JSON as a single file in the caches directory.
/// (The OS may purge caches under storage pressure; the bundle is the backstop.)
struct FilePortfolioCache: PortfolioCache {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `Caches/portfolio-cache.json`, falling back to the temporary directory if
    /// the caches directory cannot be resolved.
    static func standard() -> FilePortfolioCache {
        let fileManager = FileManager.default
        let directory = (try? fileManager.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? fileManager.temporaryDirectory
        return FilePortfolioCache(fileURL: directory.appendingPathComponent("portfolio-cache.json"))
    }

    func read() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
