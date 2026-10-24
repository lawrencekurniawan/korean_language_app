# Sori

**Sori (소리)** is a personal, offline-first Korean learning app for iPhone.

It combines four study areas with a structured curriculum:

- **Learn** — 15 expanded Vitamin Korean 1 lessons with typed exercises, pronunciation drills, and Korean Grammar in Use references
- **Practice** — one-minute reading and typing sprints measured in characters per minute (CPM)
- **Speak** — phrase-by-phrase pronunciation practice with a bundled neural Korean voice
- **Progress** — CPM trends, session history, and time spent per tab

There is no account, no analytics, and no server. Speech synthesis runs entirely on the
iPhone. Network access is used only when you explicitly download a library pack or a
subtitle file.

## Status

Milestone 9 — Expanded VK1 curriculum, typed practice, and neural TTS. Complete.

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Scaffold, theme, settings, database, app shell | Complete |
| M1 | Corpus, library, PDF/SRT import, 95% rule | Complete |
| M2 | Reading practice | Complete |
| M3 | Typing practice + 두벌식 keyboard | Complete |
| M4 | Speak tab + TTS | Complete |
| M5 | Vitamin Korean 1 curriculum + textbook audio | Complete |
| M6 | FSRS review for grammar and vocabulary | Complete |
| M7 | Progress charts, session management, time tracking | Complete |
| M8 | SideStore IPA, backup/restore, polish | Complete |
| M9 | Expanded VK1 content, typed exercises, Supertonic neural TTS | Complete |

## Requirements

- Xcode 26 or newer (built with Xcode 27.1 / iOS 26.5 SDK)
- iOS 18.0+ deployment target, iPhone only
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```sh
xcodegen generate
xcodebuild -scheme Sori \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Run tests:

```sh
xcodebuild -scheme Sori \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

The unit-test target includes a real CoreML synthesis and playback check against the
bundled Supertonic model, so the first test run downloads nothing but does use several
seconds of CPU/GPU time.

Run the UI smoke test (lesson playback, pronunciation rows, and a typed answer):

```sh
xcodebuild -scheme SoriUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

Build an unsigned Release IPA for SideStore:

```sh
./scripts/build-ipa.sh
# build/Sori.ipa
```

The script uses `CODE_SIGNING_ALLOWED=NO` and packages `Payload/Sori.app` without an
embedded provisioning profile. The bundle ID is stable at
`com.lawrencekurniawan.sori`, and the app declares no paid entitlements. SideStore
signs the IPA with your own Apple ID.

## Project structure

```
Sori/
  App/            App entry point, environment, tab shell, splash coordination
  DesignSystem/   Colours, typography, cards, buttons
  Domain/         Settings, backups, value models, corpus filtering, answer checking
  Data/           SQLite (GRDB), repositories, importers, network clients, speech engines
  Features/       Learn, Practice, Speak, Progress, Settings, backups, Library, Splash
  Resources/      Assets, localisation catalogue, starter library, Supertonic CoreML models
SoriTests/        Unit, content, speech, and importer tests
SoriUITests/      End-to-end lesson playback and typed-answer smoke test
scripts/          Seed-library generation and packaging scripts
```

`project.yml` is the source of truth for the Xcode project. `Sori.xcodeproj` is generated
and intentionally ignored.

The bundled Supertonic-3 model is about 131 MB and is copied into `Sori.app/Supertonic3`
as a folder reference. It is never downloaded at runtime.

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

Speech uses **Supertonic 3 CoreML**, a multilingual flow-matching diffusion TTS
model, through the `SpeechEngine` protocol. Four bundled Korean styles are
available: Sori Female 1–3 and Sori Male 1. The default is **Automatic**, which
chooses a neural voice and works entirely offline. Previous installs that had
selected Apple's Yuna voice migrate to Automatic automatically.

The first phrase loads the CoreML stages and may take a moment; later phrases use
a local WAV cache. Text longer than the Korean chunk limit (57 characters) and
unexpected model errors fall back to the best installed Apple Korean voice, so
playback never silently disappears. Apple Premium or Enhanced voices can be
installed in iOS Settings → Accessibility → Spoken Content → Voices → Korean and
selected explicitly if preferred.

Speak never writes practice sessions, exposure records, or analytics. Nothing is
uploaded, and no audio is recorded.

The Supertonic model assets are distributed under the BigScience Open RAIL-M
license and the Swift integration is adapted from FluidAudio (Apache 2.0). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the license files under
`Sori/Resources/Models/Supertonic3/`.

## Learn curriculum

Learn follows the **Vitamin Korean 1** sequence in 15 expanded lessons across five
chapters: Hangeul, introductions, time and dates, places and locations, and plans
and hopes. Every lesson stays at TOPIK 1 and takes about 18–24 minutes. Explanations
are in English first, with Korean examples, and no romanisation after Hangul is
introduced.

The expanded curriculum contains 376 vocabulary entries, 73 grammar points, 116
pronunciation rows, 101 dialogue lines, and 120 typed exercises. Each lesson has
5–6 goals, 16–35 vocabulary items, 4–6 grammar points, a short conversation where
appropriate, a pronunciation section, a culture note, and **Korean Grammar in Use:
Beginning** references. Play buttons appear beside every vocabulary item, grammar
example, dialogue line, and pronunciation row.

The explanations, examples, dialogues, and exercises are original study material
written for Sori; textbook pages and textbook audio are not included. The curriculum
is authored content under CC BY-NC-SA 4.0, and its version is shown in Settings.

### Typed practice

Every lesson ends with eight typed exercises. Four answer styles are used:

- **Fill in the blank** — complete a Korean sentence or grammar form
- **English → Korean** — produce the Korean sentence yourself
- **Korean → English** — explain the meaning in English
- **Open response** — compare forms, explain a rule, or describe a pronunciation

Answers are normalised for punctuation, spacing, case, and common English
contractions, and lessons can list accepted alternatives. A near miss still shows
the model answer and a useful explanation rather than only saying “wrong”.
Open-response questions are never marked wrong: they show a model answer, preserve
your response, and let you continue.

The Learn tab shows a Continue card for the next unfinished lesson, the review
queue, chapter progress, a collapsible TOPIK 1–6 roadmap, and the chapter list.
Opening a lesson marks it in progress; **Mark lesson complete** records it locally
in SQLite and creates review cards.

### Spaced repetition

Completing a lesson creates one review card for each vocabulary item and each
grammar point, so the number of cards depends on the lesson. The Learn tab shows
how many cards are due and opens Review. Grammar cards show the point title and
pattern on the front; vocabulary cards show the Korean word. Both reveal the
explanation or English gloss plus an example where one is available.

Sori uses an FSRS-5 scheduler with the published default weights and 90% desired
retention. New cards use 1, 5, and 10 minute learning steps. **Again** returns a card
to learning or relearning, while **Hard**, **Good**, and **Easy** update FSRS stability
and difficulty and schedule the next interval. Cards are keyed by stable IDs and keep
their scheduling when the curriculum is reloaded. If lesson progress is reset, that
lesson's cards are removed. Ratings and review times stay in local SQLite; no account
or upload is involved. Review history is stored for future scheduling optimisation,
but the default weights are not personalised yet.

### Personal textbook audio

The app does not ship textbook audio. If you own the Vitamin Korean 1 audio, import
the MP3/M4A/WAV/AAC/CAF/AIFF files — or a ZIP or folder containing them — from the
Files app. Sori stores them in its private Application Support directory, matches
tracks to lessons by the last number in each file name (tracks 1–94), and shows them
on the lesson page and under **Settings → Personal audio**. Matching is best effort;
the All audio screen always lists every imported track.

Imported audio is excluded from iCloud backup and never enters the library, the
public repository, or a Release build. Delete individual tracks by swiping, or clear
the whole folder from Personal audio. The original files in Files or iCloud are not
affected.

## Progress

The Progress tab combines reading and typing net CPM on one chart. Choose 1M, 3M,
6M, 1Y, or All, and switch between daily and weekly means. Each point is the mean of
saved sessions in that day or week; manual End sessions are never saved. The latest
100 sessions are listed newest first and can be filtered by skill. Deleting a session
is permanent and updates the best CPM, chart, and session list immediately.

Time spent is recorded as active foreground intervals per top-level tab and shown as
all-time totals. Review time is counted in Learn. Intervals are written when you
change tabs or leave the app; intervals under one second are discarded. Progress has
no network access and nothing is uploaded.

## Backup and restore

Sori creates one local backup per calendar day after launch. It keeps the seven newest
daily backups and four newest weekly backups in Sori's private Application Support
directory. That backup directory is excluded from iCloud device backup, and Sori never
uploads anything on its own.

Each `.sori-backup` file is an unencrypted ZIP archive containing `manifest.json`,
`sori.sqlite`, `settings.json`, and `README.txt`. The database holds progress, practice
sessions, review scheduling, library imports, and usage time. Settings contains only
preferences. Keychain credentials and personal textbook audio are excluded.

Open Settings → Backups to create a backup, export the latest copy through the iOS
share sheet to iCloud Drive, Google Drive, or another file provider, or restore from a
file. Restoring replaces the database and settings; personal audio and Keychain keys
stay on the device.

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
Bundled Supertonic-3 model assets: BigScience Open RAIL-M.
Supertonic Swift integration adapted from FluidAudio: Apache License 2.0.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution and license locations.
