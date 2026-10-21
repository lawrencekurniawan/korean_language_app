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

Milestone 0 — project scaffold, design system, database, and app shell. Complete.

| Milestone | Scope | Status |
| --- | --- | --- |
| M0 | Scaffold, theme, settings, database, app shell | Complete |
| M1 | Corpus, library, PDF/SRT import, 95% rule | In progress |
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
  Domain/         Settings and value models
  Data/           SQLite (GRDB), migrations, repositories
  Features/       Learn, Practice, Speak, Progress, Settings, Splash
  Resources/      Assets, localisation catalogue, bundled curriculum
SoriTests/        Unit tests
scripts/          Development and packaging scripts
```

`project.yml` is the source of truth for the Xcode project. `Sori.xcodeproj` is generated
and intentionally ignored.

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
