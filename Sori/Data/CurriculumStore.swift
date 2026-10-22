import Foundation
import GRDB
import Observation

@MainActor
@Observable
final class CurriculumStore {
    @ObservationIgnored private let database: AppDatabase

    private(set) var curriculum: Curriculum
    private(set) var progress: [String: LessonProgress] = [:]
    private(set) var loadError: String?

    init(database: AppDatabase, curriculum: Curriculum? = nil, bundle: Bundle = .main) {
        self.database = database
        if let curriculum {
            self.curriculum = curriculum
        } else if let loaded = Self.loadFromBundle(bundle) {
            self.curriculum = loaded
        } else {
            self.curriculum = .empty
            self.loadError = "The curriculum could not be loaded from the app bundle."
        }
    }

    // MARK: - Loading

    nonisolated static func loadFromBundle(_ bundle: Bundle = .main) -> Curriculum? {
        guard let url = bundle.url(
            forResource: "vitamin-korean-1",
            withExtension: "json"
        ) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Curriculum.self, from: data)
    }

    static func decode(_ data: Data) throws -> Curriculum {
        try JSONDecoder().decode(Curriculum.self, from: data)
    }

    func refresh() async {
        do {
            let loaded = try await database.dbQueue.read { db -> [String: LessonProgress] in
                let records = try Row.fetchAll(db, sql: """
                    SELECT lessonId, status, lastOpenedAt, completedAt, secondsSpent
                      FROM lessonProgress
                    """)

                var result: [String: LessonProgress] = [:]
                for row in records {
                    let lessonID: String = row["lessonId"]
                    result[lessonID] = LessonProgress(
                        lessonID: lessonID,
                        status: LessonStatus(rawValue: row["status"]) ?? .notStarted,
                        lastOpenedAt: row["lastOpenedAt"],
                        completedAt: row["completedAt"],
                        secondsSpent: row["secondsSpent"]
                    )
                }
                return result
            }
            progress = loaded
        } catch {
            loadError = "Lesson progress could not be loaded. \(error.localizedDescription)"
        }
    }

    // MARK: - Progress

    func status(for lessonID: String) -> LessonStatus {
        progress[lessonID]?.status ?? .notStarted
    }

    func isCompleted(_ lessonID: String) -> Bool {
        status(for: lessonID) == .completed
    }

    func completedCount(in chapter: CurriculumChapter) -> Int {
        chapter.lessons.filter { isCompleted($0.id) }.count
    }

    func completedCount(in curriculum: Curriculum) -> Int {
        curriculum.lessons.filter { isCompleted($0.id) }.count
    }

    var completedLessonCount: Int {
        curriculum.lessons.filter { isCompleted($0.id) }.count
    }

    var completedLessonIDs: Set<String> {
        Set(progress.values.filter { $0.status == .completed }.map(\.lessonID))
    }

    var nextLesson: CurriculumLesson? {
        curriculum.lessons.first { !isCompleted($0.id) }
    }

    var lastLesson: CurriculumLesson? {
        curriculum.lessons.last
    }

    func lesson(forTrack number: Int) -> CurriculumLesson? {
        curriculum.lesson(forTrack: number)
    }

    func markOpened(_ lessonID: String, at date: Date = Date()) async {
        let existing = progress[lessonID]
        let status: LessonStatus = existing?.status == .completed ? .completed : .inProgress

        do {
            try await database.dbQueue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO lessonProgress
                            (lessonId, status, lastOpenedAt, completedAt, secondsSpent)
                        VALUES (?, ?, ?, NULL, 0)
                        ON CONFLICT(lessonId) DO UPDATE SET
                            lastOpenedAt = excluded.lastOpenedAt,
                            status = CASE
                                WHEN lessonProgress.status = 'completed' THEN 'completed'
                                ELSE excluded.status
                            END
                        """,
                    arguments: [lessonID, status.rawValue, date]
                )
            }
        } catch {
            loadError = "Lesson progress could not be saved. \(error.localizedDescription)"
        }

        progress[lessonID] = LessonProgress(
            lessonID: lessonID,
            status: status,
            lastOpenedAt: date,
            completedAt: existing?.completedAt,
            secondsSpent: existing?.secondsSpent ?? 0
        )
    }

    func complete(_ lessonID: String, at date: Date = Date()) async {
        let existing = progress[lessonID]

        do {
            try await database.dbQueue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO lessonProgress
                            (lessonId, status, lastOpenedAt, completedAt, secondsSpent)
                        VALUES (?, 'completed', ?, ?, 0)
                        ON CONFLICT(lessonId) DO UPDATE SET
                            status = 'completed',
                            lastOpenedAt = excluded.lastOpenedAt,
                            completedAt = excluded.completedAt
                        """,
                    arguments: [lessonID, date, date]
                )
            }
        } catch {
            loadError = "Lesson progress could not be saved. \(error.localizedDescription)"
        }

        progress[lessonID] = LessonProgress(
            lessonID: lessonID,
            status: .completed,
            lastOpenedAt: date,
            completedAt: existing?.completedAt ?? date,
            secondsSpent: existing?.secondsSpent ?? 0
        )
    }

    func resetProgress() async {
        do {
            try await database.dbQueue.write { db in
                try db.execute(sql: "DELETE FROM lessonProgress")
            }
            progress = [:]
        } catch {
            loadError = "Lesson progress could not be reset. \(error.localizedDescription)"
        }
    }
}
