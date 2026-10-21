import Foundation

struct OpenSubtitlesSearchResponse: Decodable, Sendable {
    let totalPages: Int
    let totalCount: Int
    let page: Int
    let data: [OpenSubtitlesItem]

    enum CodingKeys: String, CodingKey {
        case totalPages = "total_pages"
        case totalCount = "total_count"
        case page
        case data
    }
}

struct OpenSubtitlesItem: Decodable, Sendable {
    let id: String?
    let attributes: OpenSubtitlesAttributes
}

struct OpenSubtitlesAttributes: Decodable, Sendable {
    let language: String
    let downloadCount: Int
    let hearingImpaired: Bool?
    let votes: Int?
    let ratings: Double?
    let fromTrusted: Bool?
    let foreignPartsOnly: Bool?
    let aiTranslated: Bool?
    let machineTranslated: Bool?
    let release: String?
    let uploader: OpenSubtitlesUploader?
    let featureDetails: OpenSubtitlesFeature?
    let files: [OpenSubtitlesFile]

    enum CodingKeys: String, CodingKey {
        case language
        case downloadCount = "download_count"
        case hearingImpaired = "hearing_impaired"
        case votes
        case ratings
        case fromTrusted = "from_trusted"
        case foreignPartsOnly = "foreign_parts_only"
        case aiTranslated = "ai_translated"
        case machineTranslated = "machine_translated"
        case release
        case uploader
        case featureDetails = "feature_details"
        case files
    }
}

struct OpenSubtitlesUploader: Decodable, Sendable {
    let name: String?
    let rank: String?
}

struct OpenSubtitlesFeature: Decodable, Sendable {
    let imdbId: Int?
    let title: String?
    let year: Int?
    let seasonNumber: Int?
    let episodeNumber: Int?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case title
        case year
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
    }
}

struct OpenSubtitlesFile: Decodable, Sendable {
    let fileId: Int
    let fileName: String?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileName = "file_name"
    }
}

struct OpenSubtitlesLoginResponse: Decodable, Sendable {
    let token: String
    let status: Int?
}

struct OpenSubtitlesDownloadResponse: Decodable, Sendable {
    let link: String
    let fileName: String
    let remaining: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case link
        case fileName = "file_name"
        case remaining
        case message
    }
}

struct DownloadedSubtitle: Sendable {
    let data: Data
    let fileName: String
    let remaining: Int?
    let link: URL?
}

struct OpenSubtitlesClient: Sendable {
    let apiKey: String
    let userAgent: String
    let session: URLSession
    let baseURL: URL

    init(
        apiKey: String,
        userAgent: String = "Sori/0.1 (iOS; personal Korean learning app)",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.userAgent = userAgent
        self.session = session
        self.baseURL = URL(string: "https://api.opensubtitles.com/api/v1")!
    }

    func search(query: String, page: Int = 1) async throws -> OpenSubtitlesSearchResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenSubtitlesError.missingAPIKey
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("subtitles"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "languages", value: "ko"),
            URLQueryItem(name: "type", value: "all"),
            URLQueryItem(name: "order_by", value: "download_count"),
            URLQueryItem(name: "order_direction", value: "desc"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "ai_translated", value: "exclude"),
            URLQueryItem(name: "machine_translated", value: "exclude"),
            URLQueryItem(name: "hearing_impaired", value: "exclude")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try Self.decodeSearch(data)
    }

    func login(username: String, password: String) async throws -> OpenSubtitlesLoginResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenSubtitlesError.missingAPIKey
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode([
            "username": username,
            "password": password
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(OpenSubtitlesLoginResponse.self, from: data)
    }

    func download(fileID: Int, token: String) async throws -> DownloadedSubtitle {
        var request = URLRequest(url: baseURL.appendingPathComponent("download"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["file_id": fileID])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let payload = try JSONDecoder().decode(OpenSubtitlesDownloadResponse.self, from: data)
        guard let link = URL(string: payload.link) else {
            throw OpenSubtitlesError.invalidResponse
        }

        var fileRequest = URLRequest(url: link)
        fileRequest.timeoutInterval = 120
        fileRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (fileData, fileResponse) = try await session.data(for: fileRequest)
        try validate(response: fileResponse, data: fileData)
        guard !fileData.isEmpty else {
            throw OpenSubtitlesError.invalidResponse
        }

        return DownloadedSubtitle(
            data: fileData,
            fileName: payload.fileName,
            remaining: payload.remaining,
            link: link
        )
    }

    static func decodeSearch(_ data: Data) throws -> OpenSubtitlesSearchResponse {
        try JSONDecoder().decode(OpenSubtitlesSearchResponse.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OpenSubtitlesError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(OpenSubtitlesErrorPayload.self, from: data)
            throw OpenSubtitlesError.api(
                payload?.message ?? "OpenSubtitles returned HTTP \(http.statusCode)."
            )
        }
    }
}

private struct OpenSubtitlesErrorPayload: Decodable {
    let message: String?
}

enum OpenSubtitlesError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an OpenSubtitles API key in Sources first."
        case .invalidResponse:
            "OpenSubtitles returned an unreadable response."
        case .api(let message):
            message
        }
    }
}
