import SwiftUI

struct LibraryArticleDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let article: LibraryArticle

    @State private var sentences: [String] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SoriSpacing.lg) {
                VStack(alignment: .leading, spacing: SoriSpacing.xs) {
                    HStack(spacing: 6) {
                        SoriBadge(text: article.kind.title, tint: .soriAccent)
                        if let license = article.license {
                            SoriBadge(text: license, tint: .soriSecondary)
                        }
                        if article.isArchived {
                            SoriBadge(text: "Archived", tint: .soriWarning)
                        }
                    }
                    Text(article.title)
                        .font(SoriFont.title)
                        .foregroundStyle(Color.soriInk)
                    Text(article.source)
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriSecondary)
                }

                SoriCard {
                    VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                        detailRow("Sentences", "\(article.sentenceCount)")
                        detailRow("Text size", TextNormalizer.formatBytes(article.byteSize))
                        if let level = article.averageDifficulty {
                            detailRow("Estimated level", "Level \(level)")
                        }
                        detailRow(
                            "Imported",
                            article.importedAt.formatted(date: .long, time: .shortened)
                        )
                        if let attribution = article.attribution {
                            detailRow("Attribution", attribution)
                        }
                    }
                }

                if let url = article.sourceURL {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                            Text("Open original source")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriAccent)
                        .padding(SoriSpacing.md)
                        .background(Color.soriSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.soriBorder, lineWidth: 1)
                        )
                    }
                }

                VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                    SoriSectionHeader("First sentences", subtitle: "Preview of the practice text")
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(SoriSpacing.lg)
                    } else if sentences.isEmpty {
                        Text("No sentences are stored for this article.")
                            .font(SoriFont.caption)
                            .foregroundStyle(Color.soriSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                            ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in
                                Text(sentence)
                                    .font(SoriFont.reading(20))
                                    .foregroundStyle(Color.soriInk)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(SoriSpacing.md)
                        .background(Color.soriSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.soriBorder, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(SoriSpacing.lg)
        }
        .soriScreenBackground()
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            sentences = (try? await env.library.articleSentences(articleID: article.id)) ?? []
            isLoading = false
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SoriSpacing.sm) {
            Text(label)
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
            Spacer(minLength: SoriSpacing.sm)
            Text(value)
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriInk)
                .multilineTextAlignment(.trailing)
        }
    }
}
