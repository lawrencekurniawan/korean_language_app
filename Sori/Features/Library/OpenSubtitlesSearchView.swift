import SwiftUI

struct OpenSubtitlesSearchView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var candidates: [SubtitleCandidate] = []
    @State private var isSearching = false
    @State private var downloadingID: Int?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var relaxed = false
    @State private var hasSearched = false
    @State private var showingSources = false

    private var openSubtitlesAPIKey: String {
        SecretStore.shared.value(for: .openSubtitlesAPIKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var openSubtitlesUsername: String {
        SecretStore.shared.value(for: .openSubtitlesUsername)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var openSubtitlesPassword: String {
        SecretStore.shared.value(for: .openSubtitlesPassword) ?? ""
    }

    private var omdbAPIKey: String {
        SecretStore.shared.value(for: .omdbAPIKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasSearchKey: Bool { !openSubtitlesAPIKey.isEmpty }
    private var hasDownloadCredentials: Bool {
        !openSubtitlesUsername.isEmpty && !openSubtitlesPassword.isEmpty
    }

    var body: some View {
        List {
            if !hasSearchKey {
                Section {
                    setupCard
                }
            } else {
                Section {
                    HStack(spacing: SoriSpacing.xs) {
                        TextField("Movie or series title", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { Task { await search() } }
                        Button {
                            Task { await search() }
                        } label: {
                            if isSearching {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                    }

                    if omdbAPIKey.isEmpty {
                        Label(
                            "Add an OMDb key in Sources to verify IMDb title ratings. Downloads stay disabled until the rating is known.",
                            systemImage: "info.circle"
                        )
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                    }

                    if !hasDownloadCredentials {
                        Label(
                            "Add your OpenSubtitles username and password in Sources to download files.",
                            systemImage: "person.badge.key"
                        )
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                    }

                    Button("Manage subtitle sources") {
                        showingSources = true
                    }
                    .font(SoriFont.captionStrong)
                } header: {
                    SoriSectionHeader("Search", subtitle: "Korean subtitles only")
                }

                if relaxed {
                    Section {
                        Label(
                            "Fewer than three titles met the 8.0 IMDb threshold, so the filter relaxed to 7.5.",
                            systemImage: "slider.horizontal.3"
                        )
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriWarning)
                    }
                }

                Section {
                    if isSearching {
                        HStack(spacing: SoriSpacing.sm) {
                            ProgressView()
                            Text("Searching OpenSubtitles…")
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriSecondary)
                        }
                    } else if candidates.isEmpty {
                        SoriEmptyState(
                            symbol: "captions.bubble",
                            title: hasSearched ? "No matches" : "Find a Korean subtitle",
                            message: hasSearched
                                ? "Try a Korean or English title, or import an SRT/VTT file from the Library screen."
                                : "Search by film or series title. Results are checked against the quality filter before download."
                        )
                    } else {
                        ForEach(candidates) { candidate in
                            candidateRow(candidate)
                        }
                    }
                } header: {
                    SoriSectionHeader(
                        "Results",
                        subtitle: candidates.isEmpty ? nil : "\(candidates.count) candidates"
                    )
                }
            }

            if let successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle.fill")
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriCorrect)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        .soriScreenBackground()
        .navigationTitle("OpenSubtitles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingSources) {
            NavigationStack {
                SourcesSettingsView()
            }
        }
        .alert(
            "OpenSubtitles",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: SoriSpacing.sm) {
            Label("Connect OpenSubtitles", systemImage: "key.horizontal")
                .font(SoriFont.headline)
                .foregroundStyle(Color.soriInk)
            Text("Add a free OpenSubtitles API key to search Korean subtitles. OMDb and an OpenSubtitles account are also needed to verify and download results.")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add keys") {
                showingSources = true
            }
            .font(SoriFont.captionStrong)
            .foregroundStyle(Color.soriAccent)
        }
        .padding(.vertical, 4)
    }

    private func candidateRow(_ candidate: SubtitleCandidate) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: SoriSpacing.xs) {
                Text(candidate.displayTitle)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                    .lineLimit(2)
                Spacer(minLength: 0)
                SoriBadge(
                    text: candidate.isEligible ? "Eligible" : "Filtered",
                    tint: candidate.isEligible ? .soriCorrect : .soriWarning
                )
            }

            if !candidate.release.isEmpty {
                Text(candidate.release)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                SoriBadge(
                    text: candidate.imdbRating.map { "IMDb \(String(format: "%.1f", $0))" } ?? "IMDb unknown",
                    tint: candidate.imdbRating == nil ? .soriWarning : .soriAccent
                )
                SoriBadge(
                    text: "Sub \(candidate.subtitleRating.map { String(format: "%.1f", $0) } ?? "—") · \(candidate.votes) votes",
                    tint: .soriSecondary
                )
                SoriBadge(text: "\(candidate.downloadCount.formatted()) ↓", tint: .soriSecondary)
            }

            HStack(spacing: 6) {
                if candidate.hasTrustedUploader {
                    SoriBadge(text: "Trusted", tint: .soriCorrect)
                }
                if candidate.aiTranslated {
                    SoriBadge(text: "AI", tint: .soriError)
                }
                if candidate.machineTranslated {
                    SoriBadge(text: "MT", tint: .soriError)
                }
                if candidate.hearingImpaired {
                    SoriBadge(text: "SDH", tint: .soriWarning)
                }
                if candidate.foreignPartsOnly {
                    SoriBadge(text: "Partial", tint: .soriWarning)
                }
                if let uploader = candidate.uploaderName {
                    Text("by \(uploader)")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriTertiary)
                        .lineLimit(1)
                }
            }

            if !candidate.rejectionReasons.isEmpty {
                Text(candidate.rejectionReasons.joined(separator: " · "))
                    .font(SoriFont.caption)
                    .foregroundStyle(candidate.isEligible ? Color.soriWarning : Color.soriError)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if candidate.isEligible && hasDownloadCredentials {
                    Button {
                        Task { await download(candidate) }
                    } label: {
                        if downloadingID == candidate.fileID {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Download & import", systemImage: "arrow.down.circle")
                                .font(SoriFont.captionStrong)
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.soriAccent)
                    .disabled(downloadingID != nil)
                } else if candidate.isEligible {
                    Button("Add download credentials") {
                        showingSources = true
                    }
                    .font(SoriFont.captionStrong)
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.soriWarning)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard hasSearchKey else {
            showingSources = true
            return
        }

        isSearching = true
        hasSearched = true
        successMessage = nil
        errorMessage = nil
        candidates = []
        relaxed = false
        defer { isSearching = false }

        do {
            let client = OpenSubtitlesClient(apiKey: openSubtitlesAPIKey)
            let response = try await client.search(query: trimmed)
            var mapped = response.data.compactMap(SubtitleCandidate.init)

            if !omdbAPIKey.isEmpty {
                mapped = await enrichWithIMDb(mapped)
            }

            let outcome = SubtitleFilter().apply(to: mapped)
            candidates = outcome.candidates
            relaxed = outcome.relaxed

            if candidates.isEmpty {
                errorMessage = "No Korean subtitle results were returned. Try a different title or import a subtitle file."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func enrichWithIMDb(_ input: [SubtitleCandidate]) async -> [SubtitleCandidate] {
        let client = OMDbClient(apiKey: omdbAPIKey)
        var ratings: [Int: Double] = [:]

        await withTaskGroup(of: (Int, Double?).self) { group in
            for candidate in input {
                guard let imdbID = candidate.imdbID else { continue }
                group.addTask {
                    do {
                        return (imdbID, try await client.rating(imdbID: imdbID))
                    } catch {
                        return (imdbID, nil)
                    }
                }
            }
            for await (imdbID, rating) in group {
                if let rating {
                    ratings[imdbID] = rating
                }
            }
        }

        return input.map { candidate in
            var value = candidate
            value.imdbRating = candidate.imdbID.flatMap { ratings[$0] }
            return value
        }
    }

    private func download(_ candidate: SubtitleCandidate) async {
        guard hasDownloadCredentials else {
            showingSources = true
            return
        }

        downloadingID = candidate.fileID
        successMessage = nil
        defer { downloadingID = nil }

        do {
            let client = OpenSubtitlesClient(apiKey: openSubtitlesAPIKey)
            let login = try await client.login(
                username: openSubtitlesUsername,
                password: openSubtitlesPassword
            )
            let downloaded = try await client.download(
                fileID: candidate.fileID,
                token: login.token
            )
            let (subtitleData, format) = try SubtitleArchive.extract(
                data: downloaded.data,
                fileName: downloaded.fileName
            )
            let document = try SubtitleImporter.document(
                from: subtitleData,
                title: candidate.displayTitle,
                format: format,
                source: "OpenSubtitles",
                sourceURL: nil,
                license: "Personal use only",
                attribution: candidate.uploaderName.map { "Uploaded by \($0)" }
            )
            let result = try await env.importer.importDocument(document)
            await env.refreshLibrary()

            if result.wasDuplicate {
                successMessage = "“\(result.title)” is already in the library."
            } else {
                successMessage = "Added “\(result.title)” with \(result.sentenceCount) sentences."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
