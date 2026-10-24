import SwiftUI

struct TypedExerciseCard: View {
    let item: CurriculumPracticeItem
    let number: Int

    @State private var answer = ""
    @State private var evaluation: PracticeEvaluation?
    @State private var didRevealAnswer = false
    @State private var showsHint = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SoriSpacing.sm) {
            header
            prompt
            answerField

            if let evaluation {
                resultCard(evaluation)
            } else if didRevealAnswer {
                modelAnswerCard(
                    title: "Model answer",
                    answer: item.answer,
                    tint: .soriSecondary
                )
            }

            if let explanation = item.explanation, evaluation != nil || didRevealAnswer {
                Text(explanation)
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
        .padding(SoriSpacing.md)
        .background(
            Color.soriSurfaceElevated.opacity(0.55),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.soriBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exercise-\(item.id)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: SoriSpacing.xs) {
            Text("\(number)")
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriBackground)
                .frame(width: 23, height: 23)
                .background(Color.soriAccent, in: Circle())

            Label(item.kind.title, systemImage: item.kind.symbol)
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriAccent)

            Spacer(minLength: SoriSpacing.xxs)

            if item.kind.isOpen {
                SoriBadge(text: "Flexible", tint: .soriSecondary)
            }
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: SoriSpacing.xs) {
            Text(item.prompt)
                .font(SoriFont.body)
                .foregroundStyle(Color.soriInk)
                .fixedSize(horizontal: false, vertical: true)

            if let hint = item.hint {
                if showsHint {
                    Text(hint)
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                } else {
                    Button("Show hint") {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showsHint = true
                        }
                    }
                    .font(SoriFont.captionStrong)
                    .foregroundStyle(Color.soriAccent)
                }
            }
        }
    }

    private var answerField: some View {
        TextField(
            item.kind.placeholder,
            text: $answer,
            axis: .vertical
        )
        .font(SoriFont.korean(17))
        .lineLimit(1...5)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($isFocused)
        .padding(SoriSpacing.sm)
        .background(
            Color.soriSurface,
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    evaluation?.verdict == .correct
                        ? Color.soriCorrect.opacity(0.55)
                        : Color.soriBorder,
                    lineWidth: 1
                )
        )
        .submitLabel(.done)
        .onSubmit(check)
        .onChange(of: answer) { _, _ in
            if evaluation != nil || didRevealAnswer {
                evaluation = nil
                didRevealAnswer = false
            }
        }
        .accessibilityIdentifier("exercise-answer-\(item.id)")
    }

    private func resultCard(_ evaluation: PracticeEvaluation) -> some View {
        VStack(alignment: .leading, spacing: SoriSpacing.xs) {
            Label(evaluation.title, systemImage: resultSymbol(evaluation.verdict))
                .font(SoriFont.captionStrong)
                .foregroundStyle(resultTint(evaluation.verdict))

            Text(evaluation.message)
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriInk)
                .fixedSize(horizontal: false, vertical: true)

            if evaluation.verdict != .open {
                HStack(alignment: .top, spacing: 5) {
                    Text("Answer:")
                        .font(SoriFont.captionStrong)
                        .foregroundStyle(Color.soriSecondary)
                    Text(evaluation.correctAnswer)
                        .font(SoriFont.korean(16))
                        .foregroundStyle(Color.soriInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(evaluation.correctAnswer)
                    .font(SoriFont.korean(16))
                    .foregroundStyle(Color.soriInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SoriSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            resultTint(evaluation.verdict).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .accessibilityIdentifier("exercise-result-\(item.id)")
    }

    private func modelAnswerCard(title: String, answer: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(SoriFont.captionStrong)
                .foregroundStyle(tint)
            Text(answer)
                .font(SoriFont.korean(16))
                .foregroundStyle(Color.soriInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SoriSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }

    private var actions: some View {
        HStack(spacing: SoriSpacing.sm) {
            Button {
                check()
            } label: {
                Label(
                    evaluation == nil ? "Check answer" : "Check again",
                    systemImage: "checkmark.circle"
                )
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.soriAccent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if evaluation != nil {
                Button("Try again") {
                    evaluation = nil
                    didRevealAnswer = false
                    isFocused = true
                }
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriAccent)
            } else if !didRevealAnswer {
                Button("Reveal") {
                    didRevealAnswer = true
                }
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriSecondary)
            }
        }
    }

    private func check() {
        guard let result = AnswerChecker.evaluate(answer, for: item) else { return }
        evaluation = result
        didRevealAnswer = false
        isFocused = false
    }

    private func resultTint(_ verdict: PracticeVerdict) -> Color {
        switch verdict {
        case .correct: .soriCorrect
        case .almost: .soriWarning
        case .incorrect: .soriError
        case .open: .soriAccent
        }
    }

    private func resultSymbol(_ verdict: PracticeVerdict) -> String {
        switch verdict {
        case .correct: "checkmark.circle.fill"
        case .almost: "exclamationmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .open: "text.bubble.fill"
        }
    }
}
