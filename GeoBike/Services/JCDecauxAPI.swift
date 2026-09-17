import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL de l'API invalide."
        case .networkError(let e): return "Erreur réseau : \(e.localizedDescription)"
        case .decodingError: return "Impossible de lire la réponse du serveur."
        case .serverError(let code): return "Erreur serveur (\(code))."
        }
    }
}

final class JCDecauxAPI {
    static let shared = JCDecauxAPI()
    private init() {}

    private let apiKey = "3e50cf6fa1796139d02d7411ff43145cb54972d2"
    private let baseURL = "https://api.jcdecaux.com/vls/v3"

    func fetchStations(contract: String) async throws -> [Station] {
        let urlString = "\(baseURL)/stations?contract=\(contract)&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([Station].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
