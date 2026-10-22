import Foundation
import Observation
import ZIPFoundation

struct PersonalAudioTrack: Identifiable, Sendable, Hashable {
    let fileName: String
    let trackNumber: Int?
    let url: URL

    var id: String { fileName }

    var displayName: String {
        if let trackNumber {
            return "Track \(String(format: "%03d", trackNumber))"
        }
        return (fileName as NSString).deletingPathExtension
    }
}

@MainActor
@Observable
final class PersonalAudioStore {
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored let directory: URL

    private(set) var tracks: [PersonalAudioTrack] = []
    private(set) var lastError: String?

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let base = (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? fileManager.temporaryDirectory
            self.directory = base
                .appendingPathComponent("Sori", isDirectory: true)
                .appendingPathComponent("PersonalAudio", isDirectory: true)
        }

        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        Self.excludeFromBackup(self.directory, fileManager: fileManager)
        reload()
    }

    // MARK: - Queries

    func tracks(for lesson: CurriculumLesson) -> [PersonalAudioTrack] {
        tracks.filter { track in
            guard let number = track.trackNumber else { return false }
            return lesson.audioTracks.contains(number)
        }
    }

    var hasTracks: Bool {
        !tracks.isEmpty
    }

    // MARK: - Import

    @discardableResult
    func importSources(_ urls: [URL]) -> Int {
        lastError = nil
        var imported = 0

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            if url.pathExtension.lowercased() == "zip" {
                imported += importZip(at: url)
            } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                imported += importDirectory(at: url)
            } else if Self.isAudioFile(url) {
                if copyAudio(from: url) { imported += 1 }
            }
        }

        reload()
        return imported
    }

    private func importDirectory(at url: URL) -> Int {
        let contents = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var imported = 0
        for child in contents {
            if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                imported += importDirectory(at: child)
            } else if Self.isAudioFile(child), copyAudio(from: child) {
                imported += 1
            }
        }
        return imported
    }

    private func importZip(at url: URL) -> Int {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            var imported = 0
            for entry in archive where entry.type == .file {
                let fileName = (entry.path as NSString).lastPathComponent
                guard !fileName.hasPrefix("."),
                      !entry.path.lowercased().contains("__macosx"),
                      let fileExtension = Self.audioExtension(of: entry.path) else {
                    continue
                }
                let destination = destinationURL(
                    for: entry.path,
                    fileExtension: fileExtension
                )
                try? fileManager.removeItem(at: destination)
                do {
                    _ = try archive.extract(entry, to: destination)
                    imported += 1
                } catch {
                    lastError = "Some audio files could not be extracted. \(error.localizedDescription)"
                }
            }
            return imported
        } catch {
            lastError = "The ZIP archive could not be opened. \(error.localizedDescription)"
            return 0
        }
    }

    private func copyAudio(from url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        guard Self.audioExtensions.contains(fileExtension) else { return false }
        let destination = destinationURL(for: url.lastPathComponent, fileExtension: fileExtension)
        do {
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: url, to: destination)
            return true
        } catch {
            lastError = "An audio file could not be imported. \(error.localizedDescription)"
            return false
        }
    }

    private func destinationURL(for fileName: String, fileExtension: String) -> URL {
        if let number = Self.trackNumber(from: fileName) {
            return directory.appendingPathComponent(
                "track-\(String(format: "%03d", number)).\(fileExtension)"
            )
        }

        let base = (fileName as NSString).deletingPathExtension
        let safe = base.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
        let trimmed = safe.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let name = trimmed.isEmpty ? UUID().uuidString : trimmed
        return directory.appendingPathComponent("\(name).\(fileExtension)")
    }

    // MARK: - Maintenance

    func reload() {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        tracks = urls
            .filter(Self.isAudioFile)
            .map { url in
                PersonalAudioTrack(
                    fileName: url.lastPathComponent,
                    trackNumber: Self.trackNumber(from: url.lastPathComponent),
                    url: url
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.trackNumber, rhs.trackNumber) {
                case let (left?, right?):
                    if left != right { return left < right }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }
                return lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
            }
    }

    func delete(_ track: PersonalAudioTrack) {
        try? fileManager.removeItem(at: track.url)
        reload()
    }

    func clear() {
        for track in tracks {
            try? fileManager.removeItem(at: track.url)
        }
        reload()
    }

    // MARK: - Parsing

    nonisolated static let audioExtensions: Set<String> = [
        "mp3", "m4a", "wav", "aac", "caf", "aiff", "aif"
    ]

    nonisolated static func isAudioFile(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
    }

    nonisolated static func audioExtension(of path: String) -> String? {
        let fileExtension = (path as NSString).pathExtension.lowercased()
        return audioExtensions.contains(fileExtension) ? fileExtension : nil
    }

    /// Reads the last one-to-three digit group in a file name. Textbook packs use
    /// names such as `비타민한국어1_001.mp3`, so the final group is the track.
    nonisolated static func trackNumber(from fileName: String) -> Int? {
        let name = ((fileName as NSString).lastPathComponent as NSString)
            .deletingPathExtension
        let pattern = try? NSRegularExpression(pattern: "(?<!\\d)\\d{1,3}(?!\\d)")
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        let matches = pattern?.matches(in: name, range: range) ?? []
        guard let match = matches.last,
              let swiftRange = Range(match.range, in: name),
              let number = Int(name[swiftRange]),
              number > 0 else {
            return nil
        }
        return number
    }

    private static func excludeFromBackup(_ url: URL, fileManager: FileManager) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
    }
}
