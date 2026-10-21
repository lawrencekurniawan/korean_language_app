import Foundation

struct OMDbClient: Sendable {
    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// OpenSubtitles stores IMDb IDs as integers, while OMDb expects `tt`
    /// prefixed IDs. A zero ID means the title was not matched.
    func rating(imdbID: Int?) async throws -> Double? {
        guard let imdbID, imdbID > 0 else { return nil }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OMDbError.missingAPIKey
        }

        let identifier = "tt" + String(imdbID)
        var components = URLComponents(string: "https://www.omdbapi.com/")!
        components.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "i", value: identifier)
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("Sori/0.1 (iOS; personal Korean learning app)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OMDbError.invalidResponse
        }

        let payload = try JSONDecoder().decode(OMDbResponse.self, from: data)
        guard payload.response == "True" else {
            throw OMDbError.api(payload.error ?? "No IMDb rating found.")
        }
        return payload.imdbRating.flatMap(Double.init)
    }
}

private struct OMDbResponse: Decodable {
    let response: String
    let imdbRating: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case response = "Response"
        case imdbRating
        case error = "Error"
    }
}

enum OMDbError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an OMDb API key in Sources to verify IMDb ratings."
        case .invalidResponse:
            "OMDb returned an unreadable response."
        case .api(let message):
            message
        }
    }
}
