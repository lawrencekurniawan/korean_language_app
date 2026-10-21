import Combine
import SwiftUI

struct TypingSessionView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let sentences: [PracticeSentence]
    let plannedDuration: Int
    let fontSize: Double
    let keyboardMode: KeyboardMode

    @State private var input = TypingInputState()
    @State private var currentIndex = 0
    @State private var furthestReachedIndex = 0
    @State private var completedCount = 0
    @State private var completedCorrectCharacters = 0
    @State private var completedTypedCharacters = 0
    @State private var startedAt = Date()
    @State private var elapsedSeconds: Double = 0
    @State private var isRunning = true
    @State private var isFinishing = false
    @State private var result: TypingResult?
    @State private var showingDiscardConfirmation = false
    @State private var pausedAt: Date?
    @State private var errorMessage: String?
    @State private var didStart = false
    @FocusState private var systemFieldFocused: Bool

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

    private var liveMetrics: TypingMetrics {
        TypingMetrics.calculate(
            target: currentSentence?.text ?? "",
            input: input.text,
            completedCorrectCharacters: completedCorrectCharacters,
            completedTypedCharacters: completedTypedCharacters,
            elapsedSeconds: max(elapsedSeconds, 0.1)
        )
    }

    var body: some View {
        ZStack {
            Color.soriBackground.ignoresSafeArea()

            if let result {
                resultView(result)
            } else {
                typingView
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            guard !didStart else { return }
            didStart = true
            startedAt = Date()
            isRunning = true

            if keyboardMode == .system {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    systemFieldFocused = true
                }
            }

            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--typing-result") {
                let target = currentSentence?.text ?? ""
                let metrics = TypingMetrics.calculate(
                    target: target,
                    input: target,
                    completedCorrectCharacters: 0,
                    completedTypedCharacters: 0,
                    elapsedSeconds: Double(plannedDuration)
                )
                isRunning = false
                result = TypingResult(
                    metrics: metrics,
                    completedSentences: 1,
                    elapsedSeconds: Double(plannedDuration),
                    saveFailed: false
                )
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
        .onChange(of: input.text) { _, newValue in
            guard result == nil, !isFinishing, let target = currentSentence?.text else {
                return
            }
            if newValue == target {
                advance()
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
            Button("Keep typing", role: .cancel) {
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

    private var typingView: some View {
        VStack(spacing: 0) {
            HStack(spacing: SoriSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Typing")
                        .font(SoriFont.headline)
                        .foregroundStyle(Color.soriInk)
                    Text("\(completedCount) completed · \(keyboardLabel)")
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

            Spacer(minLength: SoriSpacing.sm)

            if let sentence = currentSentence {
                SoriCard {
                    VStack(alignment: .leading, spacing: SoriSpacing.md) {
                        HStack(spacing: 6) {
                            SoriBadge(
                                text: "Sentence \(currentIndex + 1)",
                                tint: .soriAccent
                            )
                            SoriBadge(
                                text: "Level \(sentence.difficulty)",
                                tint: .soriSecondary
                            )
                            Spacer()
                            Text("\(furthestReachedIndex + 1) reached")
                                .font(SoriFont.caption)
                                .foregroundStyle(Color.soriTertiary)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: SoriSpacing.sm) {
                                Text("TYPE THIS")
                                    .font(SoriFont.captionStrong)
                                    .foregroundStyle(Color.soriTertiary)
                                targetText(target: sentence.text, input: input.text)
                                    .font(SoriFont.reading(fontSize))
                                    .lineSpacing(7)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Divider()
                                    .overlay(Color.soriBorder)

                                Text("YOU TYPED")
                                    .font(SoriFont.captionStrong)
                                    .foregroundStyle(Color.soriTertiary)
                                typedText(target: sentence.text, input: input.text)
                                    .font(SoriFont.reading(fontSize * 0.78))
                                    .lineSpacing(5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxHeight: keyboardMode == .builtIn ? 250 : 180)
                    }
                }
                .padding(.horizontal, SoriSpacing.lg)
            }

            statsRow
                .padding(.horizontal, SoriSpacing.lg)
                .padding(.top, SoriSpacing.sm)

            Spacer(minLength: SoriSpacing.sm)

            if keyboardMode == .builtIn {
                TypingKeyboardView { key in
                    input.press(key)
                }
            } else {
                systemInput
            }
        }
    }

    private var keyboardLabel: String {
        keyboardMode == .builtIn ? "2-set" : "System keyboard"
    }

    private var statsRow: some View {
        HStack(spacing: SoriSpacing.sm) {
            statTile(
                label: "NET CPM",
                value: String(format: "%.0f", liveMetrics.netCPM)
            )
            statTile(
                label: "ACCURACY",
                value: input.text.isEmpty
                    ? "—"
                    : String(format: "%.0f%%", liveMetrics.accuracy * 100)
            )
            statTile(
                label: "ERRORS",
                value: "\(liveMetrics.errorCharacters)"
            )
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.soriInk)
                .monospacedDigit()
            Text(label)
                .font(SoriFont.caption)
                .foregroundStyle(Color.soriSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SoriSpacing.sm)
        .background(Color.soriSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.soriBorder, lineWidth: 1)
        )
    }

    private var systemInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("System keyboard")
                .font(SoriFont.captionStrong)
                .foregroundStyle(Color.soriSecondary)
            TextField("Tap here and type the sentence", text: $input.text, axis: .vertical)
                .font(SoriFont.reading(fontSize))
                .foregroundStyle(Color.soriInk)
                .lineLimit(1...3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($systemFieldFocused)
                .padding(SoriSpacing.md)
                .background(
                    Color.soriSurface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            systemFieldFocused ? Color.soriAccent : Color.soriBorder,
                            lineWidth: 1
                        )
                )
        }
        .padding(.horizontal, SoriSpacing.lg)
        .padding(.bottom, SoriSpacing.md)
    }

    @ViewBuilder
    private func resultView(_ result: TypingResult) -> some View {
        VStack(spacing: SoriSpacing.lg) {
            Spacer()

            Image(systemName: result.saveFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(result.saveFailed ? Color.soriWarning : Color.soriCorrect)

            VStack(spacing: SoriSpacing.xxs) {
                Text(result.saveFailed ? "Session finished" : "Session complete")
                    .font(SoriFont.headline)
                    .foregroundStyle(Color.soriSecondary)
                Text(String(format: "%.0f", result.metrics.netCPM))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.soriInk)
                    .contentTransition(.numericText())
                Text("net characters per minute")
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriSecondary)
            }

            HStack(spacing: SoriSpacing.sm) {
                resultTile(
                    value: "\(result.completedSentences)",
                    label: "Completed"
                )
                resultTile(
                    value: result.metrics.typedCharacters == 0
                        ? "—"
                        : String(format: "%.0f%%", result.metrics.accuracy * 100),
                    label: "Accuracy"
                )
                resultTile(
                    value: Int(result.elapsedSeconds.rounded()).soriClock,
                    label: "Time"
                )
            }
            .padding(.horizontal, SoriSpacing.lg)

            SoriCard {
                Text("Net CPM = correct non-space characters ÷ elapsed minutes. Spaces and errors are not counted; completed sentences are still saved.")
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

    private func targetText(target: String, input: String) -> Text {
        let targetCharacters = Array(target)
        let inputCharacters = Array(input)
        var text = Text("")

        for (index, character) in targetCharacters.enumerated() {
            let color: Color
            if index < inputCharacters.count {
                color = inputCharacters[index] == character ? .soriCorrect : .soriError
            } else {
                color = .soriSecondary
            }
            text = text + Text(String(character)).foregroundColor(color)
        }

        if inputCharacters.count > targetCharacters.count {
            for character in inputCharacters[targetCharacters.count...] {
                text = text + Text(String(character)).foregroundColor(.soriError)
            }
        }

        return text
    }

    private func typedText(target: String, input: String) -> Text {
        let targetCharacters = Array(target)
        let inputCharacters = Array(input)

        guard !inputCharacters.isEmpty else {
            return Text("Start typing…").foregroundColor(.soriTertiary)
        }

        var text = Text("")
        for (index, character) in inputCharacters.enumerated() {
            let isCorrect = index < targetCharacters.count
                && character == targetCharacters[index]
            text = text + Text(String(character))
                .foregroundColor(isCorrect ? .soriCorrect : .soriError)
        }
        return text
    }

    private func advance() {
        guard let sentence = currentSentence, result == nil, !isFinishing else {
            return
        }

        completedCount += 1
        let count = TextNormalizer.nonWhitespaceCount(sentence.text)
        completedCorrectCharacters += count
        completedTypedCharacters += count
        input.reset()

        if currentIndex + 1 < sentences.count {
            currentIndex += 1
            furthestReachedIndex = max(furthestReachedIndex, currentIndex)
        } else {
            Task { await finish() }
        }
    }

    private func requestEnd() {
        guard result == nil, !isFinishing else { return }
        pausedAt = Date()
        isRunning = false
        systemFieldFocused = false
        showingDiscardConfirmation = true
    }

    private func resumeAfterPause() {
        guard !isFinishing else { return }
        if let pausedAt {
            startedAt = startedAt.addingTimeInterval(Date().timeIntervalSince(pausedAt))
        }
        pausedAt = nil
        isRunning = true
        if keyboardMode == .system {
            systemFieldFocused = true
        }
    }

    @MainActor
    private func finish() async {
        guard result == nil, !isFinishing else { return }
        isRunning = false
        isFinishing = true
        systemFieldFocused = false
        defer { isFinishing = false }

        let endedAt = Date()
        let rawDuration = endedAt.timeIntervalSince(startedAt)
        let duration = min(max(rawDuration, 0.1), Double(plannedDuration))
        let metrics = TypingMetrics.calculate(
            target: currentSentence?.text ?? "",
            input: input.text,
            completedCorrectCharacters: completedCorrectCharacters,
            completedTypedCharacters: completedTypedCharacters,
            elapsedSeconds: duration
        )
        let exposedIDs = Array(sentences.prefix(furthestReachedIndex + 1)).map(\.id)

        do {
            try await env.practice.saveTypingSession(
                TypingSessionInput(
                    startedAt: startedAt,
                    endedAt: endedAt,
                    durationSeconds: duration,
                    plannedSeconds: plannedDuration,
                    typedCharacters: metrics.typedCharacters,
                    correctCharacters: metrics.correctCharacters,
                    errorCharacters: metrics.errorCharacters,
                    completedSentences: completedCount,
                    cpmNet: metrics.netCPM,
                    cpmGross: metrics.grossCPM,
                    accuracy: metrics.accuracy,
                    fontSize: fontSize,
                    keyboardMode: keyboardMode.rawValue
                ),
                exposedSentenceIDs: exposedIDs
            )
            result = TypingResult(
                metrics: metrics,
                completedSentences: completedCount,
                elapsedSeconds: duration,
                saveFailed: false
            )
        } catch {
            result = TypingResult(
                metrics: metrics,
                completedSentences: completedCount,
                elapsedSeconds: duration,
                saveFailed: true
            )
            errorMessage = error.localizedDescription
        }
    }
}

private struct TypingResult {
    let metrics: TypingMetrics
    let completedSentences: Int
    let elapsedSeconds: Double
    let saveFailed: Bool
}
