import SwiftUI

struct ReviewView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var revealed = false
    @State private var isSubmitting = false
    @State private var reviewedCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: SoriSpacing.lg) {
                if let error = env.review.errorMessage {
                    errorCard(error)
                }

                if let card = env.review.dueCards.first {
                    header
                    cardView(card)

                    if revealed {
                        ratingButtons(card)
                    } else {
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                revealed = true
                            }
                        } label: {
                            Label("Show answer", systemImage: "eye")
                        }
                        .buttonStyle(SoriPrimaryButtonStyle())
                        .accessibilityIdentifier("review-show-answer")
                    }

                    footnote
                } else {
                    emptyState
                }
            }
            .padding(SoriSpacing.lg)
            .padding(.bottom, SoriSpacing.xl)
        }
        .soriScreenBackground()
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await env.review.refresh()
        }
        .task {
            await env.prepareReview()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--review-reveal") {
                revealed = true
            }
            #endif
        }
        .onChange(of: env.review.dueCards.first?.id) { _, _ in
            revealed = false
        }
    }

    private var header: some View {
        HStack(spacing: SoriSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(env.review.dueCount) due")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)
                Text(reviewedCount == 0 ? "Grammar and vocabulary" : "\(reviewedCount) reviewed")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }

            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.soriAccent)
                .frame(width: 38, height: 38)
                .background(Color.soriAccent.opacity(0.12), in: Circle())
        }
        .padding(.horizontal, SoriSpacing.xs)
    }

    private func cardView(_ card: ReviewCard) -> some View {
        SoriCard {
            VStack(alignment: .leading, spacing: SoriSpacing.md) {
                HStack(spacing: SoriSpacing.xs) {
                    SoriBadge(text: card.kind.title)
                    Text("Lesson \(card.lessonID)")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriTertiary)
                    Spacer()
                    Text(card.state.title)
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriTertiary)
                }

                frontView(card)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, SoriSpacing.sm)

                if revealed {
                    Divider().overlay(Color.soriBorder)

                    Text(card.back)
                        .font(card.kind == .vocabulary ? SoriFont.title : SoriFont.body)
                        .foregroundStyle(Color.soriInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if let example = card.example {
                        VStack(alignment: .leading, spacing: SoriSpacing.xxs) {
                            Text("Example")
                                .font(SoriFont.captionStrong)
                                .foregroundStyle(Color.soriSecondary)
                            Text(example)
                                .font(SoriFont.body)
                                .foregroundStyle(Color.soriInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(SoriSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.soriAccent.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                } else {
                    Text("Say the answer out loud, then reveal it.")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }
            }
        }
        .accessibilityIdentifier("review-card-\(card.id)")
    }

    @ViewBuilder
    private func frontView(_ card: ReviewCard) -> some View {
        if card.kind == .grammar,
           let newline = card.front.firstIndex(of: "\n") {
            let title = String(card.front[..<newline])
            let pattern = String(card.front[card.front.index(after: newline)...])
            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                Text(title)
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriInk)
                Text(pattern)
                    .font(SoriFont.mono)
                    .foregroundStyle(Color.soriAccent)
                    .padding(.horizontal, SoriSpacing.sm)
                    .padding(.vertical, 7)
                    .background(
                        Color.soriAccent.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
        } else {
            Text(card.front)
                .font(card.kind == .vocabulary ? SoriFont.korean(42) : SoriFont.title)
                .foregroundStyle(Color.soriInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ratingButtons(_ card: ReviewCard) -> some View {
        VStack(spacing: SoriSpacing.sm) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: SoriSpacing.sm
            ) {
                ForEach(ReviewRating.allCases) { rating in
                    Button {
                        submit(cardID: card.id, rating: rating)
                    } label: {
                        VStack(spacing: 3) {
                            Label(rating.title, systemImage: rating.symbolName)
                                .font(SoriFont.headline)
                            Text(hint(for: rating))
                                .font(SoriFont.caption)
                                .opacity(0.78)
                        }
                        .foregroundStyle(tint(for: rating))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            tint(for: rating).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(tint(for: rating).opacity(0.24), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("review-rating-\(rating.title.lowercased())")
                }
            }

            Text("Again resets the card. Hard, Good, and Easy schedule it further out.")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    private var footnote: some View {
        Text("Sori schedules reviews with FSRS. Ratings stay on this iPhone and are never uploaded.")
            .font(SoriFont.caption)
            .foregroundStyle(Color.soriTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SoriSpacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: SoriSpacing.md) {
            SoriCard {
                SoriEmptyState(
                    symbol: "checkmark.circle",
                    title: env.review.cards.isEmpty ? "No cards yet" : "All caught up",
                    message: emptyMessage
                )
            }
            .accessibilityIdentifier("review-empty")

            if !env.review.cards.isEmpty {
                Button("Check again") {
                    Task { await env.review.refresh() }
                }
                .buttonStyle(SoriSecondaryButtonStyle())
            }
        }
    }

    private var emptyMessage: String {
        if env.review.cards.isEmpty {
            return "Complete a lesson in Learn. Its grammar and vocabulary become review cards."
        }
        if let next = env.review.nextDueAt {
            return "The next card is due \(next.formatted(.relative(presentation: .named)))."
        }
        return "There are no cards waiting for review."
    }

    private func errorCard(_ message: String) -> some View {
        SoriCard {
            Label {
                Text(message)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriInk)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.soriWarning)
            }
        }
    }

    private func hint(for rating: ReviewRating) -> String {
        switch rating {
        case .again: "Forgot"
        case .hard: "Difficult"
        case .good: "Recalled"
        case .easy: "Easy"
        }
    }

    private func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: .soriError
        case .hard: .soriWarning
        case .good: .soriCorrect
        case .easy: .soriAccent
        }
    }

    private func submit(cardID: String, rating: ReviewRating) {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            let saved = await env.review.submit(cardID: cardID, rating: rating)
            if saved {
                reviewedCount += 1
            }
            isSubmitting = false
        }
    }
}
