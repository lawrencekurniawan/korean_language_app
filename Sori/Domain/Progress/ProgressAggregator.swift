import Foundation

enum ProgressAggregator {
    static func points(
        from samples: [CPMSessionSample],
        range: ProgressRange,
        aggregation: ProgressAggregation,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CPMPoint] {
        let cutoff = range.startDate(now: now, calendar: calendar)
        var buckets: [BucketKey: Bucket] = [:]

        for sample in samples {
            if let cutoff, sample.startedAt < cutoff {
                continue
            }

            let date = bucketStart(
                for: sample.startedAt,
                aggregation: aggregation,
                calendar: calendar
            )
            let key = BucketKey(date: date, skill: sample.skill)
            var bucket = buckets[key] ?? Bucket()
            bucket.sum += sample.cpm
            bucket.count += 1
            buckets[key] = bucket
        }

        return buckets
            .map { key, bucket in
                CPMPoint(
                    skill: key.skill,
                    date: key.date,
                    cpm: bucket.sum / Double(bucket.count)
                )
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.skill.rawValue < rhs.skill.rawValue
            }
    }

    private static func bucketStart(
        for date: Date,
        aggregation: ProgressAggregation,
        calendar: Calendar
    ) -> Date {
        switch aggregation {
        case .daily:
            calendar.startOfDay(for: date)
        case .weekly:
            calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }

    private struct BucketKey: Hashable {
        let date: Date
        let skill: PracticeSkill
    }

    private struct Bucket {
        var sum = 0.0
        var count = 0
    }
}
