# Sori — Project Brief

Last updated: 2026-10-24  
Status: **M9 complete**; `main` at `fba5ce2`  
App version: **1.1.0 (2)**  
Simulator: dedicated **Sori** iPhone 17, UDID `7656F99E-96A7-4407-B0B7-279596894AB3`

This is the fast onboarding document for a new engineer or model. Read this first, then
the code and [README.md](README.md). It deliberately covers architecture, product
guardrails, data flow, release process, and known gaps rather than every implementation
detail.

---

## 1. What Sori is

Sori (소리) is a personal, offline-first Korean learning app for iPhone. It combines:

- **Learn** — 15 expanded Vitamin Korean 1 lessons with vocabulary, grammar,
  pronunciation, dialogues, culture notes, typed exercises, and KGIU references.
- **Practice** — one-minute reading and typing sprints measured in characters per
  minute (CPM).
- **Speak** — phrase-by-phrase pronunciation practice with bundled neural Korean TTS.
- **Progress** — CPM charts, session history, review load, and time spent per tab.

There is no account, no analytics, and no Sori server. Network access happens only when
the user explicitly searches/downloads a library pack or subtitle file.

---

## 2. Non-negotiable guardrails

Treat these as product requirements, not suggestions.

- **Offline first.** The app must work without a network. The Supertonic model is bundled;
  never download it at runtime.
- **No accounts, analytics, telemetry, or server.** Do not add a backend dependency.
- **No copyrighted content in the repo or public build.** `reference/` and
  `LocalContent/` are gitignored. Never commit PDFs, textbook audio, subtitles, exam
  papers, OCR, or credentials. The curriculum is original authored content.
- **English-first explanations.** Korean examples, English explanations. No Hanja in the
  curriculum. No romanisation after Hangul is introduced; Hangeul drills use English
  phonetic descriptions instead.
- **Typed practice only.** Exercise types are fill-in-the-blank, English → Korean,
  Korean → English, and open response. No multiple choice.
- **Non-punitive feedback.** Closed answers use normalised matching and accepted
  alternatives. Open responses always show a model answer and are never marked wrong.
- **SideStore build.** Unsigned IPA, stable bundle ID `com.lawrencekurniawan.sori`,
  iPhone-only, no paid entitlements, no embedded provisioning profile.
- **Dedicated simulator only.** Use the Sori simulator above. Do not use shared
  simulators for development or testing.
- **Generated project.** `project.yml` is the source of truth. `Sori.xcodeproj` is
  generated and ignored. Run `xcodegen generate` after changing sources, resources, or
  project settings.
- **Local-first data.** Progress, sessions, reviews, settings, and usage stay on device.
  Backups are local ZIPs; Keychain credentials and personal audio are excluded.

---

## 3. Stack

- **Swift 6**, SwiftUI, Observation (`@Observable`), strict concurrency (`complete`).
- **iOS 18.0+**, iPhone only, Xcode 27.1 / iOS 26.5 SDK used for builds.
- **GRDB 7.11.1** for SQLite; one on-disk database for user data and library.
- **ZIPFoundation 0.9.20** for backups.
- **CoreML + AVFoundation** for bundled Supertonic 3 neural TTS.
- **XcodeGen** for project generation.
- **XCTest** for unit tests; **XCUITest** for one end-to-end smoke test.

No web views, no JS runtime, no third-party UI framework.

---

## 4. Repository map

```text
Sori/
  App/            App entry, AppEnvironment, tab shell, splash coordination
  DesignSystem/   Theme, colours, typography, reusable cards/buttons
  Domain/         Models, settings, practice logic, review, speech, backups, usage
  Data/           GRDB database, repositories, importers, network clients, TTS engines
  Features/       Learn, Practice, Speak, Progress, Review, Library, Settings, Splash
  Resources/      Assets, curriculum JSON, starter library, licences, Supertonic model
SoriTests/        159 unit tests
SoriUITests/      End-to-end lesson/playback/typed-answer smoke test
scripts/          Seed-library generation and unsigned IPA packaging
reference/        Local-only copyrighted references (gitignored, never commit)
LocalContent/     Local-only personal content (gitignored, never commit)
```

`Sori/Resources/Models/Supertonic3/` is a **folder reference** copied into
`Sori.app/Supertonic3`; it is excluded from the normal source glob and added as a
resource build phase in `project.yml`.

---

## 5. Runtime architecture and data flow

### Launch

`SoriApp` creates one `AppEnvironment.live()` and injects it into `RootTabView`.
`AppEnvironment.prepareAtLaunch()`:

1. seeds the starter library if needed,
2. loads the curriculum,
3. syncs FSRS review cards,
4. runs the daily backup if due,
5. prewarms the neural speech engine.

`AppEnvironment` owns the database, settings, repositories, speech player, usage
tracker, and backup service. Views read it from the SwiftUI environment.

### Persistence

`AppDatabase` owns a GRDB `DatabaseQueue` at
`Application Support/Sori/sori.sqlite`. It runs versioned migrations for articles,
sentences, sessions, lesson progress, review cards, usage intervals, and metadata.
`SettingsStore` uses `UserDefaults` for preferences only.

### Learn data flow

`Sori/Resources/Content/curriculum/vitamin-korean-1.json` is decoded by
`CurriculumStore` into `Curriculum`, `CurriculumChapter`, and `CurriculumLesson`.
`LessonDetailView` renders the lesson and writes lesson progress through
`CurriculumStore`. Completing a lesson calls `ReviewStore.sync(...)`, which creates one
FSRS card per vocabulary item and grammar point.

### Practice data flow

`PracticeRepository` selects sentences from the local library, and
`ReadingMetrics`/`TypingMetrics` compute CPM. Completed sessions are saved to SQLite;
manual End sessions are discarded. `UsageTracker` records foreground intervals per
top-level tab and flushes them on tab change or background.

### Speech data flow

`SpeakPlayer` is the UI-facing facade. It calls a `SpeechEngine` implementation:

- `NeuralSpeechEngine` — default. Loads the bundled Supertonic 3 CoreML pipeline,
  synthesises 44.1 kHz mono audio, caches 16-bit PCM WAVs under
  `Caches/NeuralSpeech`, and plays them with `AVAudioPlayer`.
- `AppleSpeechEngine` — fallback. Uses `AVSpeechSynthesizer` with the best installed
  Korean voice.

`SpeechVoice.best` prefers neural > premium > enhanced > standard; Yuna is deliberately
deprioritised on ties. Existing Yuna settings migrate to Automatic (neural) at launch.

### Backup data flow

`BackupService` creates a `.sori-backup` ZIP containing `manifest.json`, `sori.sqlite`,
`settings.json`, and `README.txt`. It keeps seven daily and four weekly backups in
Application Support, excluded from iCloud device backup. Keychain credentials and
personal textbook audio are excluded.

---

## 6. Feature notes

### Learn

- 5 chapters, 15 lessons, 376 vocabulary entries, 73 grammar points, 116 pronunciation
  rows, 101 dialogue lines, 120 typed exercises.
- Each lesson: 5–6 goals, 16–35 vocabulary items, 4–6 grammar points, pronunciation,
  culture note, KGIU references, 8 typed exercises, 18–24 minutes.
- Play buttons beside every vocabulary item, grammar example, dialogue line, and
  pronunciation row.
- Typed exercises use `AnswerChecker`: normalised punctuation/spacing/case, accepted
  alternatives, edit-distance "Almost", and `.open` for open responses.
- Lesson progress is local; completion creates review cards.

### Practice

- Reading and typing use a shuffled set of up to 120 sentences.
- Reading CPM excludes spaces; punctuation counts. The current sentence is not counted
  until advanced.
- Typing uses a built-in 두벌식 keyboard by default, with an iOS system-keyboard option.
- Typing filters out sentences that cannot be produced by the keyboard (Hanja, Latin,
  archaic jamo, unsupported punctuation).
- At 95% library coverage the app prompts for more real content instead of repeating
  sentences.

### Speak

- Auto mode draws a short natural phrase from the library; manual mode accepts typed or
  pasted Korean.
- Word chips speak one word; Play phrase repeats according to the saved setting
  (1–5 times, or loop when repeat = 0).
- Voice, speed, repeat count, and font size persist.
- No audio is recorded and no Speak session is written.

### Progress

- Reading and typing net CPM on one chart; 1M/3M/6M/1Y/All ranges; daily/weekly means.
- Session list, deletion, best CPM, streak, due reviews, minutes this week.
- Usage time is foreground active time per top-level tab; review time counts in Learn.

### Library and imports

- Bundled starter library: 219 openly licensed Korean articles (~1.7 MB, ~9,600
  sentences) from Korean Wikipedia (CC BY-SA 4.0) and Korean Wikisource (public domain).
- Imports: PDF text layer with Vision OCR fallback, EPUB spine order, SRT/VTT subtitles,
  plain text (UTF-8/EUC-KR/CP949).
- Optional OpenSubtitles search with quality filters; OMDb ratings; credentials in
  Keychain, device-only, excluded from backups.
- Library hard cap: 10 MB; target: 2 MB.

### Review

- FSRS-5 scheduler with published default weights and 90% desired retention.
- New cards: 1, 5, 10 minute learning steps.
- Again/Hard/Good/Easy update stability and difficulty.
- Cards keyed by stable IDs so curriculum reloads preserve scheduling.
- Reset lesson progress removes that lesson's cards.

### Personal textbook audio

- No textbook audio is shipped. Users may import their own MP3/M4A/WAV/AAC/CAF/AIFF or
  ZIP/folder.
- Stored in private Application Support, excluded from iCloud backup and Release builds.
- Matched to lessons by the last number in the filename (tracks 1–94), best effort.

---

## 7. Curriculum coverage (M9 snapshot)

This is a scope comparison against the local Vitamin Korean 1 reference, not a claim
that the book was copied. The curriculum is an original English-first rewrite.

- **Chapters/units:** 5/5 chapters, 15/15 units represented. **100% structural coverage.**
- **Core grammar:** 35/36 VK1 target grammar points have a dedicated matching-unit
  card. The one exception is `-(으)세요①` (honorific polite, VK1 2-3); the request form
  `-(으)세요②` is covered in 4-3. Strict one-to-one card coverage is therefore ~97%.
- **Core unit vocabulary:** using 199 discrete items from the textbook's unit vocabulary
  boxes (excluding number/date tables and reading-passage words), **189 (95%)** are
  explicit Sori vocabulary entries and **195 (98%)** appear somewhere in lesson content.
  The few gaps include `언제`, `내일`, `밑`, and `한국 사람` as a standalone entry.
- **Full textbook index:** about 500 headwords including numbers, place names, and
  reading words. Roughly **75% appear somewhere** in Sori and roughly **50% are explicit
  taught vocabulary**. The rest are not core unit targets.
- **Dialogues:** 12/12 post-Hangeul units have a dialogue; 101 original lines vs about
  48 textbook lines. Situations are covered and expanded, not copied.
- **Culture:** 5/5 chapter themes are represented with original notes.
- **Exercises:** 120 original typed exercises, 8 per lesson. Textbook exercises were not
  copied; they were used as a model for scope.
- **Hangeul:** 3/3 units; basic vowels/consonants, tense/aspirated consonants, compound
  vowels, finals, double finals, liaison, and seven representative finals.

Headline: **100% of the VK1 syllabus structure, ~95%+ of the core teachable content, and
~75% of the full printed-word index.** It is a scope-matched rewrite, not a reproduction.

---

## 8. Neural TTS details

- Model: **Supertonic 3 CoreML**, INT8 L128 vector estimator, bundled under
  `Sori/Resources/Models/Supertonic3/` (~131 MB).
- Weight files: vector estimator 64,214,944 bytes (~61.2 MiB), vocoder 50,672,512 bytes
  (~48.3 MiB), text encoder 18,022,016 bytes (~17.2 MiB), duration predictor ~1.8 MB.
- Four voices: `supertonic:F1`, `F2`, `F3`, `M1`; Automatic resolves to `F1`.
- Pipeline: unicode/text processing → text encoder → duration predictor → latent sampler
  → vector estimator → vocoder. 8 denoising steps by default.
- Output: 44.1 kHz mono Float32; cached as 16-bit PCM WAV.
- Long text is split at 57 CJK characters (70 Latin) and synthesised in sequence.
- Speed is baked into synthesis; `AVAudioPlayer.enableRate` is false.
- Unexpected model errors fall back to the best installed Apple Korean voice.
- The first phrase loads CoreML stages; launch prewarm reduces the wait.
- Model licence: BigScience Open RAIL-M. Swift integration adapted from FluidAudio
  (Apache 2.0). Licence files are bundled and listed in `THIRD_PARTY_NOTICES.md`.

---

## 9. Privacy and network

- No account, analytics, telemetry, or Sori server.
- Network only for explicit OpenSubtitles search/download and OMDb rating lookup.
- OpenSubtitles credentials live in Keychain with device-only access; excluded from
  backups.
- Local database, settings, and backups stay in Application Support.
- Personal audio is excluded from backups and Release builds.
- The starter library is public-domain/CC BY-SA content with attribution.

---

## 10. Tests, build, and release

### Commands

```sh
# Generate the Xcode project after project.yml/source/resource changes
xcodegen generate

# Unit tests (159)
xcodebuild test \
  -project Sori.xcodeproj \
  -scheme Sori \
  -destination 'platform=iOS Simulator,id=7656F99E-96A7-4407-B0B7-279596894AB3' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO

# UI smoke test (1; ~50–75 s)
xcodebuild test \
  -project Sori.xcodeproj \
  -scheme SoriUITests \
  -destination 'platform=iOS Simulator,id=7656F99E-96A7-4407-B0B7-279596894AB3' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO

# Unsigned device Release IPA
./scripts/build-ipa.sh
# build/Sori.ipa
```

### Simulator build/install

```sh
xcodebuild build \
  -project Sori.xcodeproj \
  -scheme Sori \
  -configuration Release \
  -destination 'platform=iOS Simulator,id=7656F99E-96A7-4407-B0B7-279596894AB3' \
  -derivedDataPath .build/DerivedDataReleaseSim \
  CODE_SIGNING_ALLOWED=NO

xcrun simctl install 7656F99E-96A7-4407-B0B7-279596894AB3 \
  .build/DerivedDataReleaseSim/Build/Products/Release-iphonesimulator/Sori.app
xcrun simctl launch 7656F99E-96A7-4407-B0B7-279596894AB3 \
  com.lawrencekurniawan.sori
```

The device IPA is not installable on the simulator; build a simulator slice separately.

### Release facts

- Bundle ID: `com.lawrencekurniawan.sori`
- iPhone-only (`UIDeviceFamily` = `[1]`)
- Unsigned; no embedded provisioning profile; no paid entitlements
- App size: ~150 MB; IPA: ~120 MB; model: ~131 MB
- GitHub warning: the 61.24 MiB vector-estimator weight exceeds GitHub's 50 MB
  recommendation but is below the 100 MB hard limit. The push succeeded.

---

## 11. Known gaps and risks

- **Physical iPhone/SideStore install not verified.** The phone is paired but was offline
  during development. Real-device neural quality, latency, memory, and SideStore refresh
  still need testing.
- **One strict curriculum gap:** `-(으)세요①` (honorific polite) has no dedicated 2-3
  card. The request form is taught in 4-3. A small content patch would close this.
- **A few core vocabulary items are absent from lesson content:** `언제`, `내일`, `밑`;
  `한국 사람` is not a standalone vocabulary entry. These are easy to add.
- **Full index coverage is not 100%** by design; the curriculum does not reproduce every
  reading-passage word, number form, or place name.
- **Vietnamese is scaffolded but not shipped.** `CFBundleLocalizations` includes `vi`
  and settings expose Vietnamese, but the content is English-first.
- **Model size.** The bundled model dominates app/IPA size and Git history. Do not add
  more large assets without a deliberate storage plan.
- **Runtime warning.** The real-CoreML unit test emits a QoS priority-inversion warning
  from the CoreML test path; tests pass. Investigate only if it becomes user-visible.
- **Open-response evaluation is intentionally non-punitive.** It shows a model answer
  rather than judging correctness; do not "fix" it into a strict checker.

---

## 12. Reading order for a new model

1. `README.md` — product and feature overview.
2. `project.yml` — targets, resources, version, deployment settings.
3. `Sori/App/AppEnvironment.swift` — composition root and launch sequence.
4. `Sori/Domain/Models/CurriculumModels.swift` and
   `Sori/Resources/Content/curriculum/vitamin-korean-1.json` — content schema and data.
5. `Sori/Data/CurriculumStore.swift` — bundle loading and lesson progress.
6. `Sori/Features/Learn/LessonDetailView.swift` and `TypedExerciseCard.swift` — Learn UI.
7. `Sori/Domain/Practice/AnswerChecker.swift` — answer semantics.
8. `Sori/Domain/Speech/SpeechEngine.swift`, `SpeakPlayer.swift`,
   `Sori/Data/Speech/NeuralSpeechEngine.swift`, `Sori/Data/Speech/Supertonic/` — speech.
9. `Sori/Data/AppDatabase.swift` and repositories — persistence.
10. `SoriTests/` and `SoriUITests/` — expected behaviour and regression coverage.
11. `scripts/build-ipa.sh` — SideStore packaging.

Before changing content, run the unit tests. Before releasing, build the device IPA and
verify its `Info.plist`, bundle ID, model presence, and unsigned status. Never commit
anything from `reference/` or `LocalContent/`.
