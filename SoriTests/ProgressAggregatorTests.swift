import XCTest
@testable import Sori

final class ProgressAggregatorTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }()

    func testDailyMeanGroupsBySkillAndDay() {
        let now = date(2026, 10, 22, 12)
        let samples = [
            CPMSessionSample(
                startedAt: date(2026, 10, 20, 9),
                skill: .reading,
                cpm: 100
            ),
            CPMSessionSample(
                startedAt: date(2026, 10, 20, 10),
                skill: .reading,
                cpm: 80
            ),
            CPMSessionSample(
                startedAt: date(2026, 10, 20, 11),
                skill: .typing,
                cpm: 40
            ),
            CPMSessionSample(
                startedAt: date(2026, 10, 21, 9),
                skill: .reading,
                cpm: 60
            )
        ]

        let points = ProgressAggregator.points(
            from: samples,
            range: .oneMonth,
            aggregation: .daily,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].skill, .reading)
        XCTAssertEqual(points[0].date, calendar.startOfDay(for: date(2026, 10, 20)))
        XCTAssertEqual(points[0].cpm, 90, accuracy: 0.001)
        XCTAssertEqual(points[1].skill, .typing)
        XCTAssertEqual(points[1].cpm, 40, accuracy: 0.001)
        XCTAssertEqual(points[2].skill, .reading)
        XCTAssertEqual(points[2].cpm, 60, accuracy: 0.001)
    }

    func testRangeExcludesSamplesBeforeCutoff() {
        let now = date(2026, 10, 22, 12)
        let samples = [
            CPMSessionSample(
                startedAt: date(2026, 9, 22, 11, 59),
                skill: .reading,
                cpm: 10
            ),
            CPMSessionSample(
                startedAt: date(2026, 9, 22, 12),
                skill: .reading,
                cpm: 20
            ),
            CPMSessionSample(
                startedAt: date(2026, 10, 1),
                skill: .typing,
                cpm: 30
            )
        ]

        let inRange = ProgressAggregator.points(
            from: samples,
            range: .oneMonth,
            aggregation: .daily,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(inRange.count, 2)
        XCTAssertEqual(inRange.map(\.cpm), [20, 30])

        let all = ProgressAggregator.points(
            from: samples,
            range: .all,
            aggregation: .daily,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].date, calendar.startOfDay(for: samples[0].startedAt))
        XCTAssertEqual(all[0].cpm, 15, accuracy: 0.001)
    }

    func testWeeklyMeanUsesWeekStart() {
        let now = date(2026, 10, 22, 12)
        let samples = [
            CPMSessionSample(
                startedAt: date(2026, 10, 12, 10),
                skill: .reading,
                cpm: 100
            ),
            CPMSessionSample(
                startedAt: date(2026, 10, 13, 10),
                skill: .reading,
                cpm: 60
            ),
            CPMSessionSample(
                startedAt: date(2026, 10, 19, 10),
                skill: .reading,
                cpm: 80
            ),
            CPMSessionSample(
                startedAt: date(2026, 10, 21, 10),
                skill: .typing,
                cpm: 40
            )
        ]

        let points = ProgressAggregator.points(
            from: samples,
            range: .all,
            aggregation: .weekly,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(points.count, 3)

        let firstWeek = points.filter {
            $0.skill == .reading
                && $0.date == calendar.startOfDay(for: date(2026, 10, 12))
        }
        XCTAssertEqual(firstWeek.count, 1)
        XCTAssertEqual(firstWeek[0].cpm, 80, accuracy: 0.001)

        let secondWeek = points.filter {
            $0.date == calendar.startOfDay(for: date(2026, 10, 19))
        }
        XCTAssertEqual(secondWeek.count, 2)

        if let reading = secondWeek.first(where: { $0.skill == .reading }) {
            XCTAssertEqual(reading.cpm, 80, accuracy: 0.001)
        } else {
            XCTFail("Expected a reading point in the second week")
        }

        if let typing = secondWeek.first(where: { $0.skill == .typing }) {
            XCTAssertEqual(typing.cpm, 40, accuracy: 0.001)
        } else {
            XCTFail("Expected a typing point in the second week")
        }
    }

    func testOneYearRangeDropsOldSamplesButAllKeepsThem() {
        let now = date(2026, 10, 22, 12)
        let samples = [
            CPMSessionSample(
                startedAt: date(2015, 1, 1),
                skill: .reading,
                cpm: 12
            )
        ]

        let oneYear = ProgressAggregator.points(
            from: samples,
            range: .oneYear,
            aggregation: .daily,
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(oneYear.isEmpty)

        let all = ProgressAggregator.points(
            from: samples,
            range: .all,
            aggregation: .daily,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(all.count, 1)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
