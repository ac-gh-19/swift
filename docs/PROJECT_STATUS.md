# MusicMod — Project Status

_Last updated: 2026-10-13_

## Where the project stands

The Xcode template project exists and builds. No features are implemented yet.

- App: default "Hello, world!" `ContentView`
- Unit tests: one empty placeholder test (`MusicModTests/example()`) — passes
  but tests nothing
- UI tests: template launch tests

## Architecture

Planned (see `CLAUDE.md` for the rules):

```
Views (SwiftUI)  →  ViewModels (@Observable)  →  Audio / Models (plain Swift)
     UI only           screen state & actions        AVAudioEngine graph, effects, export
```

Planned audio graph (shared by live preview and export):

```
AVAudioPlayerNode → TimePitch / Varispeed → EQ (lofi) → Reverb → MainMixer → output / file
```

## Features

| Feature | Status |
|---|---|
| Import audio file | Not started |
| Playback | Not started |
| Speed | Not started |
| Pitch | Not started |
| Reverb | Not started |
| Lofi EQ | Not started |
| Presets (Slowed+Reverb, Nightcore, Lofi) | Not started |
| Export | Not started |

## Changelog

### 2026-10-13 — Project setup
- **Added `CLAUDE.md`** — defines the project goal, tech stack, architecture
  rules, and the plan → discuss → implement → test → review → document workflow.
  Why: so every session follows the same rules and teaching approach.
- **Added this file** — the living record of status, architecture, and changes.
