import XCTest
import ZIPFoundation
@testable import Sori

final class PersonalAudioParsingTests: XCTestCase {
    func testTrackNumberUsesTheLastDigitGroup() {
        XCTAssertEqual(
            PersonalAudioStore.trackNumber(from: "비타민한국어1_001.mp3"),
            1
        )
        XCTAssertEqual(
            PersonalAudioStore.trackNumber(from: "Vitamin Korean 1_094.mp3"),
            94
        )
        XCTAssertEqual(
            PersonalAudioStore.trackNumber(from: "track-012.m4a"),
            12
        )
    }

    func testTrackNumberIgnoresMissingOrFourDigitNumbers() {
        XCTAssertNil(PersonalAudioStore.trackNumber(from: "intro.mp3"))
        XCTAssertNil(PersonalAudioStore.trackNumber(from: "2024.mp3"))
        XCTAssertNil(PersonalAudioStore.trackNumber(from: "000.mp3"))
    }

    func testAudioExtensionsAreCaseInsensitive() {
        XCTAssertTrue(PersonalAudioStore.isAudioFile(URL(fileURLWithPath: "a.MP3")))
        XCTAssertTrue(PersonalAudioStore.isAudioFile(URL(fileURLWithPath: "a.m4a")))
        XCTAssertFalse(PersonalAudioStore.isAudioFile(URL(fileURLWithPath: "a.txt")))
    }
}

@MainActor
final class PersonalAudioStoreTests: XCTestCase {
    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoriAudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testImportCopiesNumberedFilesAndIgnoresOthers() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data([0x00]).write(to: source.appendingPathComponent("비타민한국어1_001.mp3"))
        try Data([0x00]).write(to: source.appendingPathComponent("비타민한국어1_094.mp3"))
        try Data([0x00]).write(to: source.appendingPathComponent("notes.txt"))

        let store = PersonalAudioStore(directory: root.appendingPathComponent("audio"))
        let imported = store.importSources([source])

        XCTAssertEqual(imported, 2)
        XCTAssertEqual(store.tracks.count, 2)
        XCTAssertEqual(store.tracks.map(\.trackNumber), [1, 94])
        XCTAssertEqual(store.tracks.first?.fileName, "track-001.mp3")
        XCTAssertEqual(store.tracks.last?.fileName, "track-094.mp3")
    }

    func testReimportingTheSameTrackReplacesIt() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("one.mp3")
        try Data([0x00]).write(to: source)

        let store = PersonalAudioStore(directory: root.appendingPathComponent("audio"))
        XCTAssertEqual(store.importSources([source]), 1)
        XCTAssertEqual(store.importSources([source]), 1)
        XCTAssertEqual(store.tracks.count, 1)
    }

    func testTracksForLessonUseTheCurriculumRanges() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = Bundle(for: CurriculumStore.self)
        let curriculum = try XCTUnwrap(CurriculumStore.loadFromBundle(bundle))
        let lesson = try XCTUnwrap(curriculum.lesson(withID: "1-1"))

        let source = root.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data([0x00]).write(to: source.appendingPathComponent("track-001.mp3"))
        try Data([0x00]).write(to: source.appendingPathComponent("track-007.mp3"))

        let store = PersonalAudioStore(directory: root.appendingPathComponent("audio"))
        _ = store.importSources([source])

        XCTAssertEqual(store.tracks(for: lesson).map(\.trackNumber), [1])
    }

    func testClearRemovesEveryTrack() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("one.mp3")
        try Data([0x00]).write(to: source)

        let store = PersonalAudioStore(directory: root.appendingPathComponent("audio"))
        _ = store.importSources([source])
        XCTAssertFalse(store.tracks.isEmpty)

        store.clear()
        XCTAssertTrue(store.tracks.isEmpty)
    }

    func testAudioDirectoryIsExcludedFromBackup() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = PersonalAudioStore(directory: root.appendingPathComponent("audio"))
        let values = try store.directory.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        )

        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testZipImportSkipsMacOSMetadata() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let zipURL = root.appendingPathComponent("audio.zip")
        let archive = try Archive(url: zipURL, accessMode: .create)
        try add("Vitamin Korean/001.mp3", Data([0x00, 0x01]), to: archive)
        try add("__MACOSX/Vitamin Korean/._001.mp3", Data([0x02]), to: archive)
        try add(".DS_Store", Data([0x03]), to: archive)

        let store = PersonalAudioStore(directory: root.appendingPathComponent("audio"))
        let imported = store.importSources([zipURL])

        XCTAssertEqual(imported, 1)
        XCTAssertEqual(store.tracks.count, 1)
        XCTAssertEqual(store.tracks.first?.trackNumber, 1)
        XCTAssertEqual(store.tracks.first?.fileName, "track-001.mp3")
    }

    private func add(_ path: String, _ data: Data, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count)
        ) { position, size in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }
}
