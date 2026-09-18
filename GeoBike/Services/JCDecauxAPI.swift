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

    func fetchContracts(countryCode: String = "FR") async throws -> [Contract] {
        let urlString = "\(baseURL)/contracts?apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        #if DEBUG
        print("[JCDecaux] → fetchContracts() called, URL: \(urlString)")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            #if DEBUG
            print("[JCDecaux] ✗ Network error: \(error)")
            #endif
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            #if DEBUG
            print("[JCDecaux] HTTP status: \(http.statusCode)")
            #endif
            if http.statusCode != 200 { throw APIError.serverError(http.statusCode) }
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let all = try decoder.decode([Contract].self, from: data)
            let filtered = all.filter {
                $0.countryCode?.uppercased() == countryCode.uppercased() && $0.isActive
            }
            #if DEBUG
            print("[JCDecaux] ✓ total=\(all.count) FR+active=\(filtered.count)")
            if let s = all.first {
                print("[JCDecaux] sample: name=\(s.name) status=\(s.status ?? "nil") countryCode=\(s.countryCode ?? "nil")")
            }
            #endif
            return filtered
        } catch {
            #if DEBUG
            print("[JCDecaux] ✗ Decode error: \(error)")
            if let raw = String(data: data.prefix(500), encoding: .utf8) {
                print("[JCDecaux] Raw response (500 chars): \(raw)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }

    func fetchStations(contract: String) async throws -> [Station] {
        let urlString = "\(baseURL)/stations?contract=\(contract)&apiKey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        #if DEBUG
        print("[JCDecaux] → fetchStations(contract: \(contract))")
        #endif

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            #if DEBUG
            print("[JCDecaux] ✗ Stations network error: \(error)")
            #endif
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            #if DEBUG
            print("[JCDecaux] Stations HTTP status: \(http.statusCode)")
            #endif
            if http.statusCode != 200 { throw APIError.serverError(http.statusCode) }
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let stations = try decoder.decode([Station].self, from: data)
            #if DEBUG
            print("[JCDecaux] ✓ Stations decoded: \(stations.count) for \(contract)")
            #endif
            return stations
        } catch {
            #if DEBUG
            print("[JCDecaux] ✗ Stations decode error: \(error)")
            if let raw = String(data: data.prefix(500), encoding: .utf8) {
                print("[JCDecaux] Raw stations (500 chars): \(raw)")
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
}
