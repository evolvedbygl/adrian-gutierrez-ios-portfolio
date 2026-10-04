import Foundation

extension Portfolio {
    /// The bundled document, for previews and mocks. Never used by the live app path.
    static var sample: Portfolio {
        let bundle = Bundle.main
        guard
            let url = bundle.url(forResource: "portfolio", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let portfolio = try? PortfolioCoding.decode(data)
        else { return Portfolio() }
        return portfolio
    }
}
