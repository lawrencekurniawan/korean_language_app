import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var summary: LibrarySummary = .empty
    @State private var articles: [LibraryArticle] = []
    @State private var showArchived = false
    @State private var showingImporter = false
    @State private var showingSearch = false
    @State private var showingSources = false
    @State private var detailArticle: LibraryArticle?
    @State private var pendingDelete: LibraryArticle?
    @State private var isBusy = false
    @State private var busyLabel = ""
    @State private var alert: LibraryAlert?
    #if DEBUG
    @State private var didShowDebugDetail = false
    #endif

    var body: some View {
        List {
            if !debugArticlesOnly {
                if let failure = env.libraryFailure {
                    Section {
                        seedFailureCard(message: failure)
                    }
                }

                Section {
                    storageCard
                } header: {
                    SoriSectionHeader("Storage", subtitle: "Real Korean text, kept on this iPhone")
                }

                Section {
                    coverageCard
                    if summary.needsMoreContent {
                        coveragePrompt
                    }
                } header: {
                    SoriSectionHeader("Coverage", subtitle: "The library asks for more content at 95%")
                }

                Section {
                    actionRow(
                        symbol: "doc.badge.plus",
                        title: "Import a file",
                        detail: "PDF, EPUB, SRT, VTT, or plain text"
                    ) {
                        showingImporter = true
                    }
                    actionRow(
                        symbol: "captions.bubble",
                        title: "Search OpenSubtitles",
                        detail: "Korean subtitles, filtered for quality"
                    ) {
                        showingSearch = true
                    }
                    actionRow(
                        symbol: "key",
                        title: "Subtitle sources",
                        detail: "OpenSubtitles and OMDb keys"
                    ) {
                        showingSources = true
                    }
                } header: {
                    SoriSectionHeader("Add content")
                }
            }

            Section {
                if articles.isEmpty {
                    SoriEmptyState(
                        symbol: "books.vertical",
                        title: summary.activeSentenceCount == 0 ? "Building your library" : "No articles here",
                        message: summary.activeSentenceCount == 0
                            ? "The starter library is being prepared. You can also import your own Korean text."
                            : "Import a file to add real Korean reading material."
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(articles) { article in
                        articleRow(article)
                            .contentShape(Rectangle())
                            .onTapGesture { detailArticle = article }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = article
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    Task { await toggleArchive(article) }
                                } label: {
                                    Label(
                                        article.isArchived ? "Unarchive" : "Archive",
                                        systemImage: article.isArchived ? "tray.and.arrow.up" : "archivebox"
                                    )
                                }
                                .tint(.soriAccent)
                            }
                    }
                }
            } header: {
                SoriSectionHeader(
                    "Articles",
                    subtitle: "\(summary.articleCount) active · \(articles.count) shown"
                ) {
                    Button(showArchived ? "Hide archived" : "Show archived") {
                        showArchived.toggle()
                    }
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriAccent)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        .soriScreenBackground()
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSources = true
                } label: {
                    Image(systemName: "key")
                }
                .accessibilityLabel("Subtitle sources")
            }
        }
        .task { await load() }
        .task(id: env.libraryRevision) { await load() }
        .onChange(of: showArchived) { _, _ in
            Task { await load() }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileResult(result)
        }
        .sheet(item: $detailArticle) { article in
            NavigationStack {
                LibraryArticleDetailView(article: article)
            }
        }
        .sheet(isPresented: $showingSearch) {
            NavigationStack {
                OpenSubtitlesSearchView()
            }
        }
        .sheet(isPresented: $showingSources) {
            NavigationStack {
                SourcesSettingsView()
            }
        }
        .confirmationDialog(
            "Delete this article?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { article in
            Button("Delete", role: .destructive) {
                Task { await delete(article) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { article in
            Text("“\(article.title)” and its sentences will be removed. Practice history is kept.")
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay {
            if isBusy {
                busyOverlay
            }
        }
    }

    #if DEBUG
    private var debugArticlesOnly: Bool {
        ProcessInfo.processInfo.arguments.contains("--library-articles")
    }
    #else
    private var debugArticlesOnly: Bool { false }
    #endif

    // MARK: - Sections

    private var storageCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Library size")
                            .font(SoriFont.headline)
                            .foregroundStyle(Color.soriInk)
                        Text("\(TextNormalizer.formatBytes(summary.totalBytes)) of \(TextNormalizer.formatBytes(summary.targetBytes)) target")
                            .font(SoriFont.caption)
                            .foregroundStyle(Color.soriSecondary)
                    }
                    Spacer()
                    SoriBadge(
                        text: "\(Int((summary.targetProgress * 100).rounded()))%",
                        tint: summary.isAtTarget ? .soriCorrect : .soriAccent
                    )
                }

                ProgressView(value: summary.targetProgress, total: 1)
                    .tint(summary.isAtTarget ? .soriCorrect : .soriAccent)

                HStack {
                    Text("Hard cap \(TextNormalizer.formatBytes(summary.hardCapBytes))")
                    Spacer()
                    Text("\(summary.articleCount) articles")
                }
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)

                if summary.isAtTarget {
                    Text("Target reached. You can keep importing until the 10 MB hard cap.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }
            }
        }
        .listRowInsets(rowInsets)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var coverageCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sentences seen")
                            .font(SoriFont.headline)
                            .foregroundStyle(Color.soriInk)
                        Text("\(summary.seenSentenceCount) of \(summary.activeSentenceCount) active sentences")
                            .font(SoriFont.caption)
                            .foregroundStyle(Color.soriSecondary)
                    }
                    Spacer()
                    SoriBadge(
                        text: "\(Int((summary.coverage * 100).rounded()))%",
                        tint: summary.needsMoreContent ? .soriWarning : .soriAccent
                    )
                }
                ProgressView(value: summary.coverage, total: 1)
                    .tint(summary.needsMoreContent ? .soriWarning : .soriAccent)
                Text("A sentence counts as seen after it appears in Reading, Typing, or Speak.")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }
        }
        .listRowInsets(rowInsets)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var coveragePrompt: some View {
        SoriCard {
            HStack(alignment: .top, spacing: SoriSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.soriWarning)
                VStack(alignment: .leading, spacing: 4) {
                    Text("You've seen 95% of your library")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriInk)
                    Text("Add more real Korean so practice keeps introducing new sentences.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .listRowInsets(rowInsets)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func seedFailureCard(message: String) -> some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Label("Starter library didn't finish loading", systemImage: "exclamationmark.triangle.fill")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriWarning)
                Text(message)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") {
                    Task { await env.prepareLibrary() }
                }
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriAccent)
            }
        }
        .listRowInsets(rowInsets)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func actionRow(
        symbol: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SoriSpacing.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.soriAccent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriInk)
                    Text(detail)
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.soriTertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.soriSurface)
    }

    private func articleRow(_ article: LibraryArticle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: SoriSpacing.xs) {
                Text(article.title)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if article.isArchived {
                    SoriBadge(text: "Archived", tint: .soriSecondary)
                }
            }

            HStack(spacing: 6) {
                SoriBadge(text: article.kind.title, tint: .soriAccent)
                if let level = article.averageDifficulty {
                    SoriBadge(text: "Level \(level)", tint: .soriSecondary)
                }
                SoriBadge(text: "\(article.sentenceCount) sentences", tint: .soriSecondary)
            }

            Text("\(article.source) · \(TextNormalizer.formatBytes(article.byteSize)) · \(article.importedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.soriSurface)
    }

    private var busyOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            HStack(spacing: SoriSpacing.sm) {
                ProgressView()
                Text(busyLabel)
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
            }
            .padding(SoriSpacing.lg)
            .background(Color.soriSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
    }

    // MARK: - Importing

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.pdf, .plainText, .text]
        for ext in ["epub", "srt", "vtt"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
    }

    private func handleFileResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await importFile(url) }
        case .failure(let error):
            alert = LibraryAlert(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func importFile(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        isBusy = true
        busyLabel = "Reading \(url.lastPathComponent)…"
        defer { isBusy = false }

        do {
            let document = try await importedDocument(from: url)
            let result = try await env.importer.importDocument(document)
            await env.refreshLibrary()

            if result.wasDuplicate {
                alert = LibraryAlert(
                    title: "Already in library",
                    message: "“\(result.title)” has the same text as an existing article."
                )
            } else {
                alert = LibraryAlert(
                    title: "Added to library",
                    message: "“\(result.title)” added \(result.sentenceCount) sentences (\(TextNormalizer.formatBytes(result.byteSize)))."
                )
            }
        } catch {
            alert = LibraryAlert(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func importedDocument(from url: URL) async throws -> ImportedDocument {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return try await PDFImporter.document(from: url)
        case "epub":
            return try await EPUBImporter.document(from: url)
        case "srt", "vtt":
            let format: SubtitleFormat = url.pathExtension.lowercased() == "vtt" ? .vtt : .srt
            return try SubtitleImporter.document(
                from: try Data(contentsOf: url),
                title: url.deletingPathExtension().lastPathComponent,
                format: format
            )
        default:
            return try PlainTextImporter.document(from: url)
        }
    }

    // MARK: - Data

    private func load() async {
        summary = (try? await env.library.summary()) ?? .empty
        articles = (try? await env.library.articles(includeArchived: showArchived)) ?? []
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--article-detail"),
           !didShowDebugDetail,
           let first = articles.first {
            didShowDebugDetail = true
            detailArticle = first
        }
        #endif
    }

    private func toggleArchive(_ article: LibraryArticle) async {
        do {
            try await env.library.setArchived(!article.isArchived, articleID: article.id)
            await env.refreshLibrary()
        } catch {
            alert = LibraryAlert(title: "Couldn't update article", message: error.localizedDescription)
        }
    }

    private func delete(_ article: LibraryArticle) async {
        do {
            try await env.library.deleteArticle(id: article.id)
            await env.refreshLibrary()
        } catch {
            alert = LibraryAlert(title: "Couldn't delete article", message: error.localizedDescription)
        }
    }
}

private struct LibraryAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
