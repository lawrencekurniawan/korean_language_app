import Combine
import SwiftUI

struct ReadingSessionView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let sentences: [PracticeSentence]
    let plannedDuration: Int
    let fontSize: Double

    @State private var currentIndex = 0
    @State private var furthestReachedIndex = 0
    @State private var completedCount = 0
    @State private var startedAt = Date()
    @State private var elapsedSeconds: Double = 0
    @State private var isRunning = true
    @State private var isFinishing = false
    @State private var result: ReadingResult?
    @State private var showingDiscardConfirmation = false
    @State private var pausedAt: Date?
    @State private var errorMessage: String?
    @State private var didStart = false

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var currentSentence: PracticeSentence? {
        guard sentences.indices.contains(currentIndex) else { return nil }
        return sentences[currentIndex]
    }

    private var remainingSeconds: Int {
        max(0, plannedDuration - Int(elapsedSeconds.rounded(.down)))
    }

    private var timeProgress: Double {
        guard plannedDuration > 0 else { return 0 }
        return min(elapsedSeconds / Double(plannedDuration), 1)
    }

    var body: some View {
        ZStack {
            Color.soriBackground.ignoresSafeArea()

            if let result {
                resultView(result)
            } else {
                readingView
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            guard !didStart else { return }
            didStart = true
            startedAt = Date()
            isRunning = true
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--reading-result") {
                let metrics = ReadingMetrics.calculate(
                    sentences: sentences,
                    completedCount: min(5, sentences.count),
                    elapsedSeconds: Double(plannedDuration)
                )
                isRunning = false
                result = ReadingResult(metrics: metrics, saveFailed: false)
            } else if ProcessInfo.processInfo.arguments.contains("--reading-save-demo") {
                startedAt = Date().addingTimeInterval(-Double(plannedDuration))
                completedCount = min(5, sentences.count)
                furthestReachedIndex = min(4, sentences.count - 1)
                Task { await finish() }
            }
            #endif
        }
        .onReceive(ticker) { now in
            guard isRunning, result == nil, didStart else { return }
            let elapsed = now.timeIntervalSince(startedAt)
            elapsedSeconds = elapsed
            if elapsed >= Double(plannedDuration) {
                Task { await finish() }
            }
        }
        .confirmationDialog(
            "End and discard this session?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard session", role: .destructive) {
                dismiss()
            }
            Button("Keep reading", role: .cancel) {
                resumeAfterPause()
            }
        } message: {
            Text("Manual End discards the session. Only a completed timed session is saved.")
        }
        .alert(
            "Session not saved",
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

    private var readingView: some View {
        VStack(spacing: 0) {
            HStack(spacing: SoriSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriInk)
                    Text("\(completedCount) completed")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriSecondary)
                }

                Spacer()

                Text(remainingSeconds.soriClock)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(remainingSeconds <= 10 ? Color.soriWarning : Color.soriInk)

                Button("End") {
                    requestEnd()
                }
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriError)
            }
            .padding(.horizontal, SoriSpacing.lg)
            .padding(.top, SoriSpacing.sm)

            ProgressView(value: timeProgress, total: 1)
                .tint(Color.soriAccent)
                .padding(.horizontal, SoriSpacing.lg)
                .padding(.top, SoriSpacing.md)

            Spacer(minLength: SoriSpacing.lg)

            if let currentSentence {
                SoriCard {
                    VStack(alignment: .leading, spacing: SoriSpacing.lg) {
                        HStack(spacing: 6) {
                            SoriBadge(
                                text: "Sentence \(currentIndex + 1)",
                                tint: .soriAccent
                            )
                            SoriBadge(
                                text: "Level \(currentSentence.difficulty)",
                                tint: .soriSecondary
                            )
                            Spacer()
                            Text("\(furthestReachedIndex + 1) reached")
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriTertiary)
                        }

                        if currentSentence.text.count > 80 {
                            ScrollView {
                                sentenceText(currentSentence)
                            }
                            .frame(maxHeight: 390)
                        } else {
                            sentenceText(currentSentence)
                        }
                    }
                }
                .padding(.horizontal, SoriSpacing.lg)
            }

            Spacer(minLength: SoriSpacing.lg)

            HStack(spacing: SoriSpacing.sm) {
                Button {
                    previous()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .buttonStyle(SoriSecondaryButtonStyle())
                .disabled(currentIndex == 0)

                Button {
                    next()
                } label: {
                    Label(
                        currentIndex == sentences.count - 1 ? "Finish" : "Next",
                        systemImage: currentIndex == sentences.count - 1
                            ? "checkmark"
                            : "chevron.right"
                    )
                }
                .buttonStyle(SoriPrimaryButtonStyle())
                .disabled(isFinishing)
            }
            .padding(.horizontal, SoriSpacing.lg)
            .padding(.bottom, SoriSpacing.lg)

            Text("Tap Next when you finish a sentence. CPM uses completed sentences only.")
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SoriSpacing.lg)
                .padding(.bottom, SoriSpacing.md)
        }
    }

    private func sentenceText(_ sentence: PracticeSentence) -> some View {
        Text(sentence.text)
            .font(SoriFont.reading(fontSize))
            .foregroundStyle(Color.soriInk)
            .lineSpacing(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private func resultView(_ result: ReadingResult) -> some View {
        VStack(spacing: SoriSpacing.lg) {
            Spacer()

            Image(systemName: result.saveFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(result.saveFailed ? Color.soriWarning : Color.soriCorrect)

            VStack(spacing: SoriSpacing.xxs) {
                Text(result.saveFailed ? "Session finished" : "Session complete")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriSecondary)
                Text(String(format: "%.0f", result.metrics.cpm))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.soriInk)
                    .contentTransition(.numericText())
                Text("characters per minute")
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriSecondary)
            }

            HStack(spacing: SoriSpacing.sm) {
                resultTile(
                    value: "\(result.metrics.completedSentences)",
                    label: "Completed"
                )
                resultTile(
                    value: "\(result.metrics.completedCharacters)",
                    label: "Characters"
                )
                resultTile(
                    value: Int(result.metrics.elapsedSeconds.rounded()).soriClock,
                    label: "Time"
                )
            }
            .padding(.horizontal, SoriSpacing.lg)

            SoriCard {
                Text("CPM = non-space characters in completed sentences ÷ (elapsed seconds ÷ 60). Going back with Previous never lowers the count.")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SoriSpacing.lg)

            if result.saveFailed {
                Text("The result could not be written to the local database.")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriError)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(SoriPrimaryButtonStyle())
            .padding(.horizontal, SoriSpacing.lg)
            .padding(.bottom, SoriSpacing.lg)
        }
    }

    private func resultTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.soriInk)
            Text(label)
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SoriSpacing.md)
        .background(Color.soriSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.soriBorder, lineWidth: 1)
        )
    }

    private func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func next() {
        guard !isFinishing else { return }
        completedCount = max(completedCount, currentIndex + 1)

        if currentIndex + 1 < sentences.count {
            currentIndex += 1
            furthestReachedIndex = max(furthestReachedIndex, currentIndex)
        } else {
            Task { await finish() }
        }
    }

    private func requestEnd() {
        guard result == nil else { return }
        pausedAt = Date()
        isRunning = false
        showingDiscardConfirmation = true
    }

    private func resumeAfterPause() {
        if let pausedAt {
            startedAt = startedAt.addingTimeInterval(Date().timeIntervalSince(pausedAt))
        }
        pausedAt = nil
        isRunning = true
    }

    @MainActor
    private func finish() async {
        guard result == nil, !isFinishing else { return }
        isRunning = false
        isFinishing = true
        defer { isFinishing = false }

        let endedAt = Date()
        let rawDuration = endedAt.timeIntervalSince(startedAt)
        let duration = min(max(rawDuration, 0.1), Double(plannedDuration))
        let metrics = ReadingMetrics.calculate(
            sentences: sentences,
            completedCount: completedCount,
            elapsedSeconds: duration
        )
        let exposedIDs = Array(sentences.prefix(furthestReachedIndex + 1)).map(\.id)

        do {
            try await env.practice.saveReadingSession(
                ReadingSessionInput(
                    startedAt: startedAt,
                    endedAt: endedAt,
                    durationSeconds: duration,
                    plannedSeconds: plannedDuration,
                    completedCharacters: metrics.completedCharacters,
                    completedSentences: metrics.completedSentences,
                    cpm: metrics.cpm,
                    fontSize: fontSize
                ),
                exposedSentenceIDs: exposedIDs
            )
            result = ReadingResult(metrics: metrics, saveFailed: false)
        } catch {
            result = ReadingResult(metrics: metrics, saveFailed: true)
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReadingResult {
    let metrics: ReadingMetrics
    let saveFailed: Bool
}
