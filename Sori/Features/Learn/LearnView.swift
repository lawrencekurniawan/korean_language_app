import SwiftUI

struct LearnView: View {
    @AppStorage("learn.roadmapExpanded") private var roadmapExpanded = false
    @State private var showingLessonPreview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SoriSpacing.lg) {
                    continueCard
                    reviewCard
                    roadmapCard
                    footnote
                }
                .padding(SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.xl)
            }
            .soriScreenBackground()
            .navigationTitle("Learn")
            .sheet(isPresented: $showingLessonPreview) {
                LessonPreviewSheet()
            }
        }
    }

    private var continueCard: some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                HStack {
                    SoriBadge(text: "TOPIK 1")
                    Spacer()
                    Text("4 min")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                VStack(alignment: .leading, spacing: SoriSpacing.xxs) {
                    Text("Hangul, step by step")
                        .font(SoriFont.title)
                        .foregroundStyle(Color.soriInk)
                    Text("Vitamin Korean 1 · Unit 1, Lesson 1")
                        .font(SoriFont.callout)
                        .foregroundStyle(Color.soriSecondary)
                }

                Text("Learn the basic vowels, consonants, and the shape of a Korean syllable.")
                    .font(SoriFont.body)
                    .foregroundStyle(Color.soriInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Preview lesson") {
                    showingLessonPreview = true
                }
                .buttonStyle(SoriPrimaryButtonStyle())
            }
        }
    }

    private var reviewCard: some View {
        SoriCard {
            HStack(spacing: SoriSpacing.md) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.soriAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.soriAccent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviews due")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriInk)
                    Text("Spaced repetition arrives in M6")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                Spacer()

                Text("0")
                    .font(SoriFont.stat)
                    .foregroundStyle(Color.soriTertiary)
            }
        }
    }

    private var roadmapCard: some View {
        SoriCard(padding: SoriSpacing.md) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        roadmapExpanded.toggle()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Learning roadmap")
                                .font(SoriFont.headline)
                                .foregroundStyle(Color.soriInk)
                            Text("TOPIK 1 → 6")
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.soriSecondary)
                            .rotationEffect(.degrees(roadmapExpanded ? 0 : -90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if roadmapExpanded {
                    VStack(spacing: SoriSpacing.xs) {
                        ForEach(RoadmapLevel.all) { level in
                            RoadmapLevelRow(level: level)
                        }
                    }
                    .padding(.top, SoriSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var footnote: some View {
        Text("Levels 2–6 are coming in later content updates. The curriculum is bundled and versioned, so every install gets the same lessons.")
            .font(SoriFont.caption)
            .foregroundStyle(Color.soriSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SoriSpacing.xs)
    }
}

// MARK: - Roadmap

private struct RoadmapLevel: Identifiable {
    let id: Int
    let book: String
    let topic: String
    let status: Status

    enum Status {
        case current
        case planned
    }

    static let all: [RoadmapLevel] = [
        .init(id: 1, book: "Vitamin Korean 1", topic: "TOPIK 1", status: .current),
        .init(id: 2, book: "Vitamin Korean 2", topic: "TOPIK 2", status: .planned),
        .init(id: 3, book: "Vitamin Korean 3", topic: "TOPIK 3", status: .planned),
        .init(id: 4, book: "Vitamin Korean 4", topic: "TOPIK 4", status: .planned),
        .init(id: 5, book: "Vitamin Korean 5", topic: "TOPIK 5", status: .planned),
        .init(id: 6, book: "Vitamin Korean 6", topic: "TOPIK 6", status: .planned)
    ]
}

private struct RoadmapLevelRow: View {
    let level: RoadmapLevel

    var body: some View {
        HStack(spacing: SoriSpacing.sm) {
            Text("\(level.id)")
                .font(SoriFont.captionStrong)
                .foregroundStyle(level.status == .current ? Color.soriAccent : Color.soriTertiary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(
                        level.status == .current
                            ? Color.soriAccent.opacity(0.14)
                            : Color.soriSurfaceElevated
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(level.book)
                    .font(SoriFont.callout)
                    .foregroundStyle(level.status == .current ? Color.soriInk : Color.soriSecondary)
                HStack(spacing: 6) {
                    Text(level.topic)
                    Text("·")
                    Text(level.status == .current ? "Current level" : "Coming later")
                }
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
            }

            Spacer()

            if level.status == .planned {
                Image(systemName: "lock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.soriTertiary)
            } else {
                Text("0%")
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriAccent)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, SoriSpacing.xs)
    }
}

// MARK: - Lesson preview

private struct LessonPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SoriSpacing.lg) {
                    SoriBadge(text: "TOPIK 1 · 4 min")

                    Text("한글을 배워요 ①")
                        .font(SoriFont.reading(34))
                        .foregroundStyle(Color.soriInk)

                    Text("Basic vowels, basic consonants, and syllable structure.")
                        .font(SoriFont.body)
                        .foregroundStyle(Color.soriSecondary)

                    SoriCard {
                        VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                            Text("By the end of this lesson")
                                .font(SoriFont.captionStrong)
                                .foregroundStyle(Color.soriSecondary)
                            Label("Read and write ㅏ ㅓ ㅗ ㅜ ㅡ ㅣ", systemImage: "checkmark.circle")
                            Label("Recognise ㄱ ㄴ ㄷ ㄹ ㅁ ㅂ ㅅ ㅇ ㅈ ㅎ", systemImage: "checkmark.circle")
                            Label("Build a basic C + V syllable", systemImage: "checkmark.circle")
                        }
                        .font(SoriFont.body)
                        .foregroundStyle(Color.soriInk)
                    }

                    SoriCard {
                        VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                            Text("Preview")
                                .font(SoriFont.captionStrong)
                                .foregroundStyle(Color.soriSecondary)
                            Text("가 나 다 라 마 바 사")
                                .font(SoriFont.korean(34))
                                .foregroundStyle(Color.soriInk)
                            Text("Each block is one syllable: consonant + vowel.")
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriSecondary)
                        }
                    }

                    Text("Full explanations, audio, vocabulary, and review cards arrive with the curriculum milestone.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SoriSpacing.lg)
            }
            .soriScreenBackground()
            .navigationTitle("Lesson 1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
