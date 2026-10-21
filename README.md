# Sori

**Sori (소리)** is a personal, offline-first Korean learning app for iPhone.

It combines four practice loops with a structured curriculum:

- **Learn** — a deterministic Vitamin Korean 1 curriculum with Korean Grammar in Use references
- **Practice** — one-minute reading and typing sprints measured in characters per minute (CPM)
- **Speak** — phrase-by-phrase pronunciation practice with on-device speech synthesis
- **Progress** — CPM trends, session history, and time spent per tab

There is no account, no analytics, and no server. Network access is used only when you
explicitly download a library pack or a subtitle file.

## Status

Milestone 4 — Speak practice with on-device text-to-speech. Complete.

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Scaffold, theme, settings, database, app shell | Complete |
| M1 | Corpus, library, PDF/SRT import, 95% rule | Complete |
| M2 | Reading practice | Complete |
| M3 | Typing practice + 두벌식 keyboard | Complete |
| M4 | Speak tab + TTS | Complete |
| M5 | Vitamin Korean 1 curriculum + textbook audio | Planned |
| M6 | Spaced repetition review | Planned |
| M7 | Progress charts, session management, time tracking | Planned |
| M8 | SideStore IPA, backup/restore, polish | Planned |

## Requirements

- Xcode 26 or newer (built with Xcode 27.1 / iOS 26.5 SDK)
- iOS 18.0+ deployment target, iPhone only
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```sh
xcodegen generate
xcodebuild -scheme Sori \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Run tests:

```sh
xcodebuild -scheme Sori \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

## Project structure

```
Sori/
  App/            App entry point, environment, tab shell, splash coordination
  DesignSystem/   Colours, typography, cards, buttons
  Domain/         Settings, value models, corpus segmentation and filtering
  Data/           SQLite (GRDB), repositories, importers, network clients
  Features/       Learn, Practice, Speak, Progress, Settings, Library, Splash
  Resources/      Assets, localisation catalogue, starter library JSON
SoriTests/        Unit and importer tests
scripts/          Seed-library generation and packaging scripts
```

`project.yml` is the source of truth for the Xcode project. `Sori.xcodeproj` is generated
and intentionally ignored.

## Starter library

The app ships with a versioned starter library of **219 openly licensed Korean
articles** (about 1.7 MB of text and 9,600 sentences) from Korean Wikipedia
(CC BY-SA 4.0) and Korean Wikisource (public domain). Every article records its
source, URL, licence, and attribution. The library is seeded once on first launch
and can be extended by import.

The library targets 2 MB of text and enforces a 10 MB hard cap. Reading and
Typing record sentence exposure; at 95% coverage Sori prompts for more real
content instead of starting to repeat the same sentences.

### Importing

- **PDF** — text-layer extraction with Vision OCR fallback for scanned pages
- **EPUB** — spine-order chapter extraction
- **SRT / VTT** — Korean subtitle parsing with SDH, tag, and CP949 handling
- **Plain text** — UTF-8, EUC-KR, and CP949 decoding

### Subtitle search

The Library can search OpenSubtitles for Korean subtitles. Results are checked
against a quality filter: IMDb title rating ≥ 8.0 (relaxed to 7.5 when fewer than
three titles qualify), subtitle rating ≥ 7.0 with ≥ 100 votes, trusted uploader,
≥ 1,000 downloads, Korean only, and no AI, machine-translated, hearing-impaired,
or foreign-parts-only files. OMDb supplies the IMDb rating. Credentials are stored
in the iOS Keychain with device-only access and are excluded from backups.

Network access happens only when you explicitly search or download a subtitle.

## Reading practice

Reading draws a shuffled set of up to 120 active library sentences and runs for the
configured duration (15–300 seconds). The timer starts only after Start. Tap Next
when a sentence is finished or Previous to revisit one; the furthest completed
sentence is kept.

A manual End discards the session. When the timer completes, Sori saves the session
and shows the result. Reading CPM is:

```
non-whitespace characters in completed sentences ÷ (elapsed seconds ÷ 60)
```

Punctuation counts as a character; spaces do not. The sentence currently on screen
is not counted until you advance past it with Next. Completed sessions also record
sentence exposure for the 95% library-coverage rule.

## Typing practice

Typing uses the same configured duration and library source as Reading. It selects up
to 120 modern-Hangul sentences that can be produced by the built-in keyboard: Hangul
syllables, spaces, digits, and the punctuation available on the keyboard’s symbol
layer. Sentences with archaic jamo, Hanja, Latin letters, or unsupported punctuation
are skipped for typing practice.

The default keyboard is a built-in 두벌식 layout with a shift layer for double
consonants and ㅒ/ㅖ, a symbol layer for digits and punctuation, space, and delete.
The Settings tab can switch to the iOS system keyboard instead. In system-keyboard
mode, the same target and live comparison are used, but composition is handled by iOS.

Typed characters are compared with the target as you type. Correct characters turn
green, mistakes turn red, and the comparison advances to the next sentence when the
target is matched exactly. Net typing CPM is:

```
correct non-space characters ÷ (elapsed seconds ÷ 60)
```

Gross CPM and accuracy are stored as well. Spaces are excluded from both CPM values;
errors never enter the net numerator. A manual End discards the session. When the
timer completes, or when the last sentence is finished, Sori saves the session,
records exposures up to the furthest sentence shown, and displays the result.

## Speak practice

Speak has two modes. **Auto** draws a short, natural phrase from the library: at
most 10 eojeol, preferring 3–7, with digits, Hanja, jamo, brackets, and
notation-heavy text filtered out. **Manual** lets you type or paste your own
Korean text. Switching modes never clears the phrase you are working on.

Tap any word chip to hear that word once. Tap **Play phrase** to hear the whole
phrase with the saved repeat setting: 1–5 times, or loop until you press Stop.
Voice, speed, repeat, and the Speak font size persist across launches.

Speech is synthesised on-device by Apple's `AVSpeechSynthesizer` behind a small
`SpeechEngine` protocol, so a neural engine can replace it later. Automatic voice
selection uses the highest-quality Korean voice installed on the iPhone, with
Yuna preferred on ties — so a downloaded Yuna Enhanced or Premium voice is used
as soon as iOS exposes it. The voice sheet lists every Korean voice and says when
only the Standard voice is present; enhanced voices are installed in iOS
Settings → Accessibility → Spoken Content → Voices → Korean.

Speak never writes practice sessions, exposure records, or analytics. Nothing is
uploaded, and no audio is recorded.

## Personal content

The `reference/` and `LocalContent/` directories are gitignored. They may contain
copyrighted textbooks, textbook audio, subtitle files, or exam papers that are used for
personal study only. They are never committed and are never included in a public build.

The public build ships only original curriculum content and public-domain library
material. See [CONTENT-LICENSE.md](CONTENT-LICENSE.md).

## Licence

Source code: MIT (see [LICENSE](LICENSE)).
Authored curriculum: CC BY-NC-SA 4.0.
Bundled public-domain texts retain their original status.
