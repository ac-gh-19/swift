# MusicMod — Project Status

_Last updated: 2026-10-13_

## Where the project stands

Song import works ([spec 001](specs/001-song-import.md)). The app shows an
**Import Song** button; picked files are validated (format, length ≤ 5:00,
readable) and accepted songs are copied into the app's container. No playback
or effects yet.

- Unit tests: 27 passing (`SongImporterTests`, `ImportViewModelTests`, plus the
  empty template `example()`)
- UI tests: template launch tests only

## Architecture

See `CLAUDE.md` for the rules.

Current files:

```
MusicMod/
├── ContentView.swift              shows ImportView
├── Views/ImportView.swift         Import button, .fileImporter([.audio]), song info, errors
├── ViewModels/ImportViewModel.swift   current song + error messages
├── Import/SongImporter.swift      validate + copy (off the main actor via @concurrent)
└── Models/
    ├── ImportedSong.swift         copied file URL, display name, duration
    └── ImportRejection.swift      rejection reasons + user-facing messages
MusicModTests/
├── AudioFixtures.swift            generates WAV/AIFF/M4A/CAF test files of exact length
├── Fixtures/                      MP3/FLAC/OGG test files made with ffmpeg
├── SongImporterTests.swift
└── ImportViewModelTests.swift
```

Imported songs live in `Library/Application Support/Imports/<UUID>/<name>`;
only one is kept at a time.

Layering:

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
| Import audio file | ✅ Done — spec 001 |
| Playback | Not started |
| Speed | Not started |
| Pitch | Not started |
| Reverb | Not started |
| Lofi EQ | Not started |
| Presets (Slowed+Reverb, Nightcore, Lofi) | Not started |
| Export | Not started |

## Changelog

### 2026-10-13 — Song import (spec 001)
- **Added song import.** Tap Import → pick an audio file → it's checked and
  copied into the app. Why: every later feature needs a song to work on, and
  copying it into the sandbox means the app never depends on temporary file
  permissions or iCloud availability.
- **Rules:** MP3/M4A/WAV/AIFF/FLAC only; songs under 5:01 (anything a player
  shows as "5:00" or less — absorbs whole-second rounding and encoder padding);
  damaged files and failed saves get their own messages. All failing rules are
  shown together.
- **New import replaces the old one**, deleted only after the new copy is
  saved. A rejected pick leaves the current song loaded.
- **Tests** use real audio: generated tones of exact sample counts for the
  boundary, and committed ffmpeg-made MP3/FLAC/OGG files for formats iOS can't
  write.

### 2026-10-13 — Project setup
- **Added `CLAUDE.md`** — defines the project goal, tech stack, architecture
  rules, and the plan → discuss → implement → test → review → document workflow.
  Why: so every session follows the same rules and teaching approach.
- **Added this file** — the living record of status, architecture, and changes.
