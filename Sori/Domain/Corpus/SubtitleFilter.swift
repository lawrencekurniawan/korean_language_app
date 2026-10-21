import Foundation

struct SubtitleCandidate: Identifiable, Sendable {
    let id: Int
    let fileID: Int
    let title: String
    let year: Int?
    let season: Int?
    let episode: Int?
    let release: String
    let language: String
    let downloadCount: Int
    let subtitleRating: Double?
    let votes: Int
    let fromTrusted: Bool
    let uploaderName: String?
    let uploaderRank: String?
    let aiTranslated: Bool
    let machineTranslated: Bool
    let hearingImpaired: Bool
    let foreignPartsOnly: Bool
    let imdbID: Int?
    var imdbRating: Double?
    var rejectionReasons: [String] = []
    var isEligible: Bool = false

    init(
        fileID: Int,
        title: String,
        year: Int? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        release: String = "",
        language: String = "ko",
        downloadCount: Int = 0,
        subtitleRating: Double? = nil,
        votes: Int = 0,
        fromTrusted: Bool = false,
        uploaderName: String? = nil,
        uploaderRank: String? = nil,
        aiTranslated: Bool = false,
        machineTranslated: Bool = false,
        hearingImpaired: Bool = false,
        foreignPartsOnly: Bool = false,
        imdbID: Int? = nil,
        imdbRating: Double? = nil
    ) {
        self.id = fileID
        self.fileID = fileID
        self.title = title
        self.year = year
        self.season = season
        self.episode = episode
        self.release = release
        self.language = language
        self.downloadCount = downloadCount
        self.subtitleRating = subtitleRating
        self.votes = votes
        self.fromTrusted = fromTrusted
        self.uploaderName = uploaderName
        self.uploaderRank = uploaderRank
        self.aiTranslated = aiTranslated
        self.machineTranslated = machineTranslated
        self.hearingImpaired = hearingImpaired
        self.foreignPartsOnly = foreignPartsOnly
        self.imdbID = imdbID
        self.imdbRating = imdbRating
    }

    init?(item: OpenSubtitlesItem) {
        let attributes = item.attributes
        guard attributes.language == "ko",
              let file = attributes.files.first else {
            return nil
        }

        let feature = attributes.featureDetails
        let fileID = file.fileId
        guard fileID > 0 else { return nil }

        self.id = fileID
        self.fileID = fileID
        let featureTitle = (feature?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = featureTitle.isEmpty ? "Untitled" : featureTitle
        self.year = feature?.year
        self.season = feature?.seasonNumber
        self.episode = feature?.episodeNumber
        self.release = attributes.release ?? file.fileName ?? ""
        self.language = attributes.language
        self.downloadCount = attributes.downloadCount
        self.subtitleRating = attributes.ratings
        self.votes = attributes.votes ?? 0
        self.fromTrusted = attributes.fromTrusted ?? false
        self.uploaderName = attributes.uploader?.name
        self.uploaderRank = attributes.uploader?.rank
        self.aiTranslated = attributes.aiTranslated ?? false
        self.machineTranslated = attributes.machineTranslated ?? false
        self.hearingImpaired = attributes.hearingImpaired ?? false
        self.foreignPartsOnly = attributes.foreignPartsOnly ?? false
        self.imdbID = feature?.imdbId.flatMap { $0 > 0 ? $0 : nil }
        self.imdbRating = nil
    }

    var displayTitle: String {
        var value = title
        if let year { value += " (\(year))" }
        if let season, let episode {
            value += " · S\(season)E\(episode)"
        }
        return value
    }

    var hasTrustedUploader: Bool {
        fromTrusted || (uploaderRank?.lowercased().contains("trusted") ?? false)
    }
}

struct SubtitleFilter: Sendable {
    var strictIMDbRating: Double = 8.0
    var relaxedIMDbRating: Double = 7.5
    var minimumSubtitleRating: Double = 7.0
    var minimumVotes: Int = 100
    var minimumDownloads: Int = 1_000
    var relaxedThresholdCount: Int = 3

    struct Outcome: Sendable {
        var candidates: [SubtitleCandidate]
        var relaxed: Bool
        var eligibleCount: Int {
            candidates.filter(\.isEligible).count
        }
    }

    func apply(to input: [SubtitleCandidate]) -> Outcome {
        let strict = input.map { evaluate($0, threshold: strictIMDbRating) }
        let strictEligible = strict.filter(\.isEligible).count
        let canRelax = input.contains { candidate in
            guard let rating = candidate.imdbRating else { return false }
            return rating >= relaxedIMDbRating && rating < strictIMDbRating
        }
        let relaxed = strictEligible < relaxedThresholdCount && canRelax
        let threshold = relaxed ? relaxedIMDbRating : strictIMDbRating
        let evaluated = relaxed
            ? input.map { evaluate($0, threshold: threshold) }
            : strict

        let sorted = evaluated.sorted { left, right in
            if left.isEligible != right.isEligible {
                return left.isEligible
            }
            if left.imdbRating != right.imdbRating {
                return (left.imdbRating ?? 0) > (right.imdbRating ?? 0)
            }
            if left.subtitleRating != right.subtitleRating {
                return (left.subtitleRating ?? 0) > (right.subtitleRating ?? 0)
            }
            return left.downloadCount > right.downloadCount
        }

        return Outcome(candidates: sorted, relaxed: relaxed)
    }

    private func evaluate(_ candidate: SubtitleCandidate, threshold: Double) -> SubtitleCandidate {
        var value = candidate
        var reasons: [String] = []

        if value.language != "ko" {
            reasons.append("Not Korean")
        }
        if value.aiTranslated {
            reasons.append("AI translated")
        }
        if value.machineTranslated {
            reasons.append("Machine translated")
        }
        if value.hearingImpaired {
            reasons.append("Hearing impaired")
        }
        if value.foreignPartsOnly {
            reasons.append("Foreign parts only")
        }
        if !value.hasTrustedUploader {
            reasons.append("Untrusted uploader")
        }
        if value.downloadCount < minimumDownloads {
            reasons.append("Under 1,000 downloads")
        }
        if let rating = value.subtitleRating, rating > 0 {
            if rating < minimumSubtitleRating {
                reasons.append("Subtitle rating \(Self.format(rating))")
            }
        } else {
            reasons.append("No subtitle rating")
        }
        if value.votes < minimumVotes {
            reasons.append("Under 100 votes")
        }
        if let rating = value.imdbRating {
            if rating < threshold {
                reasons.append("IMDb \(Self.format(rating))")
            }
        } else {
            reasons.append("IMDb rating unavailable")
        }

        value.rejectionReasons = reasons
        value.isEligible = reasons.isEmpty
        if value.isEligible && threshold < strictIMDbRating {
            value.rejectionReasons = ["Relaxed IMDb threshold"]
        }
        return value
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
