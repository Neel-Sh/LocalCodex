import Foundation

enum ProviderHealthService {
    static func check(_ provider: LocalProvider) async -> ProviderHealth {
        var request = URLRequest(url: provider.healthURL)
        request.timeoutInterval = 1.8

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .offline("Could not read a response from \(provider.label). \(provider.startHint)")
            }

            if 200..<500 ~= http.statusCode {
                return .online
            }

            return .offline("\(provider.label) responded with HTTP \(http.statusCode). \(provider.startHint)")
        } catch {
            return .offline("Could not reach \(provider.label) at \(provider.healthURL.host ?? "localhost"). \(provider.startHint)")
        }
    }
}
