# Third-party notices

Sori includes or adapts the following third-party software and model assets.
Nothing in this file changes the licence terms of the original projects.

## Supertonic 3 CoreML model assets

- **Upstream model:** Supertone Supertonic-3
  <https://huggingface.co/Supertone/supertonic-3>
- **CoreML conversion and packaging:** FluidInference Mobius / FluidAudio
  <https://github.com/FluidInference/FluidAudio>
- **Files bundled with Sori:** `Sori/Resources/Models/Supertonic3/`
  (text encoder, duration predictor, vector estimator, vocoder, Unicode
  indexer, voice styles, configuration)
- **Licence:** BigScience Open RAIL-M
- **Licence text:** `Sori/Resources/Models/Supertonic3/LICENSE`

The model is used locally for Korean text-to-speech. Sori does not redistribute
model outputs as a service and does not use the model for any purpose prohibited
by the Open RAIL-M use restrictions.

## FluidAudio Supertonic3 Swift integration

- **Project:** FluidAudio
  <https://github.com/FluidInference/FluidAudio>
- **Files adapted:** Supertonic configuration, Unicode processing, text
  chunking, latent sampling, CoreML multi-array helpers, synthesizer, model
  store, error types, and constants under
  `Sori/Data/Speech/Supertonic/`
- **Licence:** Apache License 2.0
- **Licence text:** `Licenses/Apache-2.0.txt`
- **Upstream notice:** Copyright FluidInference and contributors.

The Sori integration replaces the upstream download manager with a
bundle-backed model store, adapts the code to Sori's Swift 6 concurrency and
`SpeechEngine` architecture, and adds WAV caching and Apple speech fallback.

## GRDB.swift

- **Project:** GRDB.swift <https://github.com/groue/GRDB.swift>
- **Use:** local SQLite database and migrations
- **Licence:** MIT
- **Copyright:** Gwendal Roué

## ZIPFoundation

- **Project:** ZIPFoundation <https://github.com/weichsel/ZIPFoundation>
- **Use:** reading and writing Sori backup and import archives
- **Licence:** MIT
- **Copyright:** Thomas Zoechling and contributors

## Apple frameworks

Sori uses Apple system frameworks including SwiftUI, AVFoundation, CoreML,
Vision, PDFKit, and Speech. These frameworks are provided by iOS and are not
redistributed with this repository.
