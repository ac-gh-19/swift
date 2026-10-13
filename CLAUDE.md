# MusicMod — CLAUDE.md

## What we're building

An iOS app that lets a user import a song file and transform it into the kind of
remixes popular on YouTube: **slowed + reverb**, **sped up / nightcore**, **lofi**,
and similar. The user can preview changes live and export the result as a new
audio file.

**Every effect has its own slider(s) the user edits manually** — manual control
is the core of the app, not an advanced extra. Core effects (initial scope —
confirm before adding more):
- **Speed** — faster/slower playback
- **Pitch** — shift up/down in semitones/cents
- **Reverb** — room/hall/cathedral style wet/dry mix
- **Lofi tone** — low-pass / high-pass EQ, optional light distortion/bitcrush
- **Presets** — one-tap "Slowed + Reverb", "Nightcore", "Lofi". A preset only
  moves the sliders to preset values; the user can keep adjusting afterward.
  Presets must not have their own separate effect logic.

Key audio concept (explain this to the user when relevant):
- *Varispeed* (tape/vinyl style): speed and pitch change together. This is how
  real "nightcore" and "slowed" edits sound.
- *Time-stretch*: speed changes while pitch stays the same (or pitch changes
  while speed stays the same).
The app should support both; which mode the UI exposes is a product decision to
discuss with the user.

## The user

This is the user's **first time using Swift and Xcode**. Treat every task as a
teaching opportunity:
- Before creating or changing anything, explain **what** you're about to do and
  **why** (which framework/API, why it fits, what the alternatives were).
- Explain Swift/SwiftUI/Xcode concepts the first time they appear (e.g.
  `struct` vs `class`, `@Observable`, `@State`, `async/await`, actors, property
  wrappers, optionals, targets, schemes, simulators, Info.plist, sandboxing).
- When writing tests, explain how the test proves the feature works — not just
  that it passes.
- After implementing, walk through how the code flows at runtime (e.g. "tap
  button → view model method → audio engine → speaker").
- Never create or implement silently. If the user may not understand something,
  stop and check.

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| Language | Swift | Native iOS language |
| UI | SwiftUI | Declarative UI, the modern Apple default |
| State | Observation (`@Observable`) | Modern replacement for `ObservableObject`; less boilerplate |
| Audio playback + effects | `AVFoundation` → `AVAudioEngine` | Built-in real-time audio graph with ready-made effect nodes |
| Effect nodes | `AVAudioUnitTimePitch` (time-stretch), `AVAudioUnitVarispeed` (tape-style speed+pitch), `AVAudioUnitReverb`, `AVAudioUnitEQ` (lofi filters), `AVAudioUnitDistortion` | No third-party DSP needed for v1 |
| Export | `AVAudioEngine` **offline manual rendering** → `AVAudioFile` | Renders the *same* effect graph used for preview to a file, faster than real time |
| File import | SwiftUI `.fileImporter` + `UTType.audio` | Native Files-app picker |
| Signal analysis (tests, waveform) | `Accelerate` (`vDSP`) | Fast FFT/RMS for verifying pitch/tempo and drawing waveforms |
| Unit tests | Swift Testing (`import Testing`, `@Test`, `#expect`) | Already set up in `MusicModTests` |
| UI tests | XCTest / XCUITest | Already set up in `MusicModUITests` |

No third-party packages (e.g. AudioKit) unless discussed with the user first —
Apple's frameworks cover v1, and fewer dependencies means less to learn.

## Project layout & settings

```
swift/                         ← git root (this file lives here)
├── CLAUDE.md
├── docs/PROJECT_STATUS.md     ← living status/architecture/changelog doc
└── MusicMod/
    ├── MusicMod.xcodeproj
    ├── MusicMod/              ← app source (target: MusicMod)
    ├── MusicModTests/         ← unit tests (Swift Testing)
    └── MusicModUITests/       ← UI tests (XCUITest)
```

Facts about this project worth knowing:
- **Xcode 27, iOS 27 deployment target**, Swift 5 language mode.
- Folders are **file-system synchronized groups**: any `.swift` file created on
  disk inside `MusicMod/MusicMod/` is automatically part of the app target — no
  need to edit `project.pbxproj`. Never hand-edit `project.pbxproj` unless
  there's no alternative; explain to the user if you must.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: all code runs on the main actor
  by default. Heavy work (offline rendering, file decoding, analysis) must be
  explicitly moved off it (`nonisolated`, `@concurrent`, or a separate actor) or
  the UI will freeze. Explain this whenever it comes up.
- Changing build settings, capabilities, Info.plist keys, or the deployment
  target is a decision for the user — propose and explain, don't just do it.

## Architecture rules

1. **UI is separate from logic.**
   - `Views/` — SwiftUI views only. Layout, bindings, user gestures. No audio
     APIs, no file I/O, no math.
   - `ViewModels/` — `@Observable` classes that hold screen state and translate
     user actions into calls on the engine/services.
   - `Audio/` (and other logic folders) — plain Swift with no `import SwiftUI`.
     This is what unit tests exercise.
   - `Models/` — simple value types (e.g. `EffectSettings`, `Preset`).
2. **No unnecessary abstractions.** No protocols with one conformer, no
   wrappers around a single API call, no "manager of managers." Add an
   abstraction only when there's a concrete second use (or a test genuinely
   needs it) — and explain why.
3. **Don't redeclare what exists.** Before writing a helper, search the codebase
   for one that already does it and reuse/extend it. One audio graph is used for
   both live preview and export — don't build two.
4. Keep files small and named after the one type they contain.

## Workflow (every spec follows this)

1. **Plan** — Read the spec and relevant code. Write a plan: files to add/change,
   APIs used, data flow, how it will be tested.
2. **Discuss** — Raise anything ambiguous or open-ended (UX choices, parameter
   ranges, file formats, edge cases) as explicit questions. Explain the plan in
   beginner-friendly terms and confirm the user understands and agrees.
   **Do not write code until the user approves the plan.**
3. **Implement** — Build exactly what was agreed. Explain new concepts as they
   appear.
4. **Test** — Tests must verify real behavior, not just pass:
   - Audio logic: generate a known signal (e.g. a 440 Hz sine), run it through
     the code, and measure the output (duration changed by the expected factor,
     dominant frequency shifted by the expected semitones, reverb tail adds
     energy after the input stops, low-pass reduces high-frequency energy).
   - Avoid tests that only assert a property was set, or that mock away the
     thing being tested.
   - Check that a test can fail: briefly confirm it fails when the behavior is
     broken.
   - Run the full suite and report actual results, including failures.
5. **Review** — Compare the result against the spec point by point and call out
   any gaps or deviations.
6. **Document** — Update `docs/PROJECT_STATUS.md`: current state, architecture,
   feature list, and a changelog entry explaining *what changed and why*.

## Commands

Run from `MusicMod/` (the folder containing `MusicMod.xcodeproj`):

```bash
# Build
xcodebuild build -project MusicMod.xcodeproj -scheme MusicMod \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -quiet

# Unit tests only (fast)
xcodebuild test -project MusicMod.xcodeproj -scheme MusicMod \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -only-testing:MusicModTests -quiet

# All tests (unit + UI; UI tests are slow)
xcodebuild test -project MusicMod.xcodeproj -scheme MusicMod \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -quiet
```

In Xcode: ⌘B build, ⌘R run in simulator, ⌘U run tests, ⌘6 Test navigator.

## Gotchas to watch for

- **Security-scoped files**: files picked via `.fileImporter` must be accessed
  inside `startAccessingSecurityScopedResource()` / `stop…`. Copy the file into
  the app's own sandbox before processing.
- **Audio session**: configure `AVAudioSession` (category `.playback`) so audio
  plays with the silent switch on and behaves well with other apps.
- **Simulator audio** works but latency/performance differs from a real device;
  test on a device before judging performance.
- **Copyright**: the app processes files the user already owns; don't add
  features that download music from streaming sites.
