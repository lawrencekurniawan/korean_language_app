import XCTest
@testable import Sori

final class SubtitleFilterTests: XCTestCase {
    func testDecodesSearchResponseAndMapsCandidate() throws {
        let json = """
        {
          "total_pages": 1,
          "total_count": 1,
          "page": 1,
          "data": [
            {
              "id": "abc",
              "attributes": {
                "language": "ko",
                "download_count": 1500,
                "hearing_impaired": false,
                "votes": 120,
                "ratings": 7.8,
                "from_trusted": true,
                "foreign_parts_only": false,
                "ai_translated": false,
                "machine_translated": false,
                "release": "Example.Release",
                "uploader": { "name": "uploader", "rank": "trusted" },
                "feature_details": {
                  "imdb_id": 1234567,
                  "title": "Example Movie",
                  "year": 2020,
                  "season_number": null,
                  "episode_number": null
                },
                "files": [
                  { "file_id": 999, "file_name": "example.srt" }
                ]
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try OpenSubtitlesClient.decodeSearch(json)
        XCTAssertEqual(response.totalPages, 1)
        XCTAssertEqual(response.data.count, 1)

        let candidate = try XCTUnwrap(SubtitleCandidate(item: response.data[0]))
        XCTAssertEqual(candidate.fileID, 999)
        XCTAssertEqual(candidate.title, "Example Movie")
        XCTAssertEqual(candidate.year, 2020)
        XCTAssertEqual(candidate.imdbID, 1234567)
        XCTAssertEqual(candidate.subtitleRating, 7.8)
        XCTAssertEqual(candidate.votes, 120)
        XCTAssertEqual(candidate.downloadCount, 1500)
        XCTAssertTrue(candidate.hasTrustedUploader)
    }

    func testStrictEligibleCandidate() {
        let outcome = SubtitleFilter().apply(to: [candidate(imdbRating: 8.3)])
        XCTAssertFalse(outcome.relaxed)
        XCTAssertEqual(outcome.eligibleCount, 1)
        XCTAssertTrue(outcome.candidates[0].isEligible)
        XCTAssertTrue(outcome.candidates[0].rejectionReasons.isEmpty)
    }

    func testRelaxesWhenFewerThanThreeCandidatesMeetEightPointZero() {
        let outcome = SubtitleFilter().apply(to: [
            candidate(fileID: 1, imdbRating: 7.8),
            candidate(fileID: 2, imdbRating: 7.4)
        ])
        XCTAssertTrue(outcome.relaxed)
        XCTAssertEqual(outcome.eligibleCount, 1)
        XCTAssertTrue(outcome.candidates.first { $0.fileID == 1 }!.isEligible)
        XCTAssertFalse(outcome.candidates.first { $0.fileID == 2 }!.isEligible)
    }

    func testDoesNotRelaxWhenNoCandidateReachesSevenPointFive() {
        let outcome = SubtitleFilter().apply(to: [
            candidate(imdbRating: 7.4),
            candidate(fileID: 2, imdbRating: 6.9)
        ])
        XCTAssertFalse(outcome.relaxed)
        XCTAssertEqual(outcome.eligibleCount, 0)
    }

    func testRejectsEveryDisallowedFlag() {
        let cases: [(SubtitleCandidate, String)] = [
            (candidate(language: "en"), "Not Korean"),
            (candidate(aiTranslated: true), "AI translated"),
            (candidate(machineTranslated: true), "Machine translated"),
            (candidate(hearingImpaired: true), "Hearing impaired"),
            (candidate(foreignPartsOnly: true), "Foreign parts only"),
            (candidate(fromTrusted: false), "Untrusted uploader"),
            (candidate(downloadCount: 999), "Under 1,000 downloads"),
            (candidate(subtitleRating: 6.9), "Subtitle rating 6.9"),
            (candidate(subtitleRating: nil), "No subtitle rating"),
            (candidate(votes: 99), "Under 100 votes"),
            (candidate(imdbRating: nil), "IMDb rating unavailable")
        ]

        for (value, reason) in cases {
            let outcome = SubtitleFilter().apply(to: [value])
            XCTAssertFalse(
                outcome.candidates[0].isEligible,
                "Expected \(reason) to make the candidate ineligible"
            )
            XCTAssertTrue(
                outcome.candidates[0].rejectionReasons.contains(reason),
                "Expected rejection reasons to contain \(reason), got \(outcome.candidates[0].rejectionReasons)"
            )
        }
    }

    func testRejectsSevenPointNineWhenStrictThresholdIsNotRelaxed() {
        let strictCandidates = (1...3).map { index in
            candidate(fileID: 100 + index, imdbRating: 8.5)
        }
        let outcome = SubtitleFilter().apply(to: [candidate(imdbRating: 7.9)] + strictCandidates)
        XCTAssertFalse(outcome.relaxed)
        let rejected = outcome.candidates.first { $0.fileID == 1 }!
        XCTAssertFalse(rejected.isEligible)
        XCTAssertTrue(rejected.rejectionReasons.contains("IMDb 7.9"))
    }

    func testSortsEligibleCandidatesFirstByIMDbRating() {
        let outcome = SubtitleFilter().apply(to: [
            candidate(fileID: 1, imdbRating: 8.1),
            candidate(fileID: 2, imdbRating: 8.7),
            candidate(fileID: 3, imdbRating: 7.0)
        ])
        XCTAssertEqual(outcome.candidates.map(\.fileID), [2, 1, 3])
    }

    private func candidate(
        fileID: Int = 1,
        language: String = "ko",
        downloadCount: Int = 5_000,
        subtitleRating: Double? = 8.0,
        votes: Int = 200,
        fromTrusted: Bool = true,
        aiTranslated: Bool = false,
        machineTranslated: Bool = false,
        hearingImpaired: Bool = false,
        foreignPartsOnly: Bool = false,
        imdbRating: Double? = 8.3
    ) -> SubtitleCandidate {
        SubtitleCandidate(
            fileID: fileID,
            title: "Test",
            release: "Test.Release",
            language: language,
            downloadCount: downloadCount,
            subtitleRating: subtitleRating,
            votes: votes,
            fromTrusted: fromTrusted,
            uploaderName: "uploader",
            uploaderRank: fromTrusted ? "trusted" : "bronze",
            aiTranslated: aiTranslated,
            machineTranslated: machineTranslated,
            hearingImpaired: hearingImpaired,
            foreignPartsOnly: foreignPartsOnly,
            imdbID: 123456,
            imdbRating: imdbRating
        )
    }
}
