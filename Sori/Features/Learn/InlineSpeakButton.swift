import SwiftUI

struct InlineSpeakButton: View {
    @Environment(AppEnvironment.self) private var env
    let text: String
    let player: SpeakPlayer
    var compact = false

    private var isActive: Bool {
        player.isSpeaking && player.speakingText == text
    }

    var body: some View {
        Button {
            if isActive {
                player.stop()
            } else {
                player.play(
                    text,
                    repeatCount: env.settings.repeatCount,
                    voiceIdentifier: env.settings.voiceIdentifier,
                    rate: env.settings.speechRate
                )
            }
        } label: {
            Image(systemName: isActive ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                .font(.system(size: compact ? 19 : 22, weight: .medium))
                .foregroundStyle(Color.soriAccent)
                .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Stop pronunciation" : "Play pronunciation")
        .accessibilityIdentifier("speak-\(text)")
    }
}
