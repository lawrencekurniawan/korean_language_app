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

Milestone 1 — corpus, starter library, importers, and subtitle search. Complete.

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Scaffold, theme, settings, database, app shell | Complete |
| M1 | Corpus, library, PDF/SRT import, 95% rule | Complete |
| M2 | Reading practice | Planned |
| M3 | Typing practice + 두벌식 keyboard | Planned |
| M4 | Speak tab + TTS | Planned |
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
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Run tests:

```sh
xcodebuild -scheme Sori \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
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

The library targets 2 MB of text and enforces a 10 MB hard cap. Reading, Typing,
and Speak record sentence exposure; at 95% coverage Sori prompts for more real
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
