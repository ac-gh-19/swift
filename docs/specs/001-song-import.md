# Spec 001 — Song Import

_Status: **Approved** — implemented_
_Created: 2026-10-13 · Updated: 2026-10-13_

## Goal

Let the user tap an **Import** button, pick a song from the Files app, and have
it imported into MusicMod so later features (playback, effects, export) can use
it. Files that aren't a supported format, are longer than 5 minutes, or can't be
read are rejected with a clear on-screen error.

## User flow

1. User taps **Import**.
2. The system Files picker opens (`.fileImporter`), showing **audio files only**
   — documents, images, etc. are greyed out and can't be picked.
3. User picks a file (or cancels — nothing happens, no error).
4. The app checks the file:
   - **Accepted** → the file is copied into the app's container, **replacing**
     any previously imported song, and the screen shows the new song's name and
     length.
   - **Rejected** → nothing is copied. The screen shows **every** error that
     applies. If a song was already imported, it **stays loaded**; the errors
     refer only to the file just picked.

## Acceptance rules

### Rule 1 — Format

Accepted formats (decided by the file's type, i.e. its extension):

| Format | Extension(s) |
|---|---|
| MP3 | `.mp3` |
| M4A (AAC or Apple Lossless) | `.m4a` |
| WAV | `.wav` |
| AIFF | `.aif`, `.aiff` |
| FLAC | `.flac` |

The picker only offers audio files, but some audio formats are still not
supported (e.g. `.ogg`, `.wma`, `.caf`, `.aac`, `.opus`, `.m4b`). Picking one of
those shows:

> **Only MP3, M4A, WAV, AIFF, and FLAC files are accepted.**

### Rule 2 — Length

Length is read from the file header via `AVAudioFile`
(`length ÷ processingFormat.sampleRate`) — no full decode needed.

The limit is 5 minutes, inclusive. Over the limit shows:

> **Only songs 5 minutes or shorter are accepted.**

The limit is a single constant in code, and the message is built from it, so
changing the limit changes the message automatically.

**Boundary rule:** accept any song whose length is
**under 5:01** (i.e. it would display as "5:00" or less in a music player).

- Music players show length in whole seconds, so a song the user sees as "5:00"
  can really be up to 300.99 s long. A strict 300.000 s cut-off would reject it.
- MP3 and M4A encoders also add a few milliseconds of silence at the start and
  end, which can push a true 5:00 song slightly over.
- Accepting under 5:01 (an extra second at most) avoids both surprises.

| Length | Result |
|---|---|
| 5:00.000 | Accepted |
| 5:00.999 | Accepted |
| 5:01.000 | Rejected |

### Rule 3 — Unreadable files

If the file has an accepted extension but `AVAudioFile` can't open it (corrupt,
truncated, mislabelled — e.g. a text file renamed to `.mp3`), show:

> **This file couldn't be read. It may be damaged or not a real audio file.**

iOS doesn't reliably tell us *why* a file can't be opened, so there is one
message for all of these cases instead of guessing at the cause.

If the extension is **not** accepted and the file also can't be opened (e.g.
`.wma`), only the format error is shown — the format error already explains the
problem, and the length is unknown.

**Limit:** this check reads the file's header only. A file with a valid header
but damaged audio further in passes import; that will surface during playback
(a later spec).

### Rule 4 — Saving fails

If the file passes every check but copying it into the app fails (e.g. the
device is out of storage, or an iCloud file can't be downloaded), show:

> **The song couldn't be saved. Check that your device has free storage and try again.**

The previously imported song stays loaded.

### Rule 5 — Report all failures, not just the first

Format and length are always both checked. If a file breaks both, **both**
messages are shown. Validation returns a *list* of problems rather than stopping
at the first one.

| File | Result |
|---|---|
| 3:30 `.mp3` | Imported |
| 5:00 `.wav` | Imported |
| 5:30 `.flac` | Length error |
| 2:00 `.caf` | Format error |
| 6:00 `.caf` | **Format error + length error** |
| `.wma` (iOS can't read it) | Format error only |
| Corrupt `.mp3` | Unreadable error |

**Note:** "fails both" is only possible when iOS *can* read the length of an
unsupported file, e.g. `.caf`, `.aac`, `.m4b`.

## Where the file goes

- Read the picked file inside `startAccessingSecurityScopedResource()` /
  `stopAccessingSecurityScopedResource()` (temporary permission from the picker).
- Validate **before** copying, so rejected files are never copied.
- Copy accepted files to `Library/Application Support/Imports/` using
  `FileManager`.
- Only one song is kept: a successful import deletes the previous copy. The old
  copy is deleted only **after** the new one is copied, so a failed copy never
  leaves the user with no song.
- The original file is never modified.

## Architecture

| Layer | File | Responsibility |
|---|---|---|
| Model | `Models/ImportedSong.swift` | Value type: local URL, display name, duration |
| Model | `Models/ImportRejection.swift` | Enum of reasons (`unsupportedFormat`, `tooLong`, `unreadable`, `saveFailed`) + user-facing message |
| Logic | `Import/SongImporter.swift` | Validate (→ list of rejections) and copy/replace. No SwiftUI. |
| ViewModel | `ViewModels/ImportViewModel.swift` | `@Observable`: holds current song + error messages, calls `SongImporter` |
| View | `Views/ImportView.swift` | Import button, `.fileImporter(allowedContentTypes: [.audio])`, song info, error list |

`ContentView` will show `ImportView` in place of the template "Hello, world!".

Data flow:

```
Tap Import → .fileImporter (audio only) → URL
  → ImportViewModel.importSong(from:)
    → SongImporter.validate(url)   → [ImportRejection]   (empty = OK)
    → SongImporter.copy(url)       → ImportedSong        (replaces old copy)
  → view shows the new song, or the error list (old song still shown)
```

**Main actor note:** reading the file header and copying a file are disk work.
Because this project runs code on the main actor by default, `SongImporter`'s
work is marked to run off the main actor so the UI doesn't stall on a large file.

## Test plan

Unit tests (Swift Testing, `MusicModTests`) call `SongImporter` directly with
real audio files — no mocks.

**Fixtures:**
- WAV, AIFF, M4A, CAF — generated at test time with `AVAudioFile` (silence or a
  440 Hz sine), so lengths are exact to the sample.
- MP3, FLAC, OGG — iOS can't write these, so short fixture files are generated
  once on the Mac with `ffmpeg` and committed under `MusicModTests/Fixtures/`.
  Long fixtures use low-bitrate mono silence to stay small.
- Corrupt `.mp3` — a file of random bytes with an `.mp3` extension.

**Cases:**

| # | Test | Proves |
|---|---|---|
| 1 | Each of MP3, M4A, WAV, AIFF, FLAC (short) → accepted, copied, copy is readable with correct duration | All 5 formats work end to end |
| 2 | `.caf`, `.ogg` (short) → exactly `[unsupportedFormat]` | Format rule rejects other audio |
| 3 | WAV of exactly 300.000 s → accepted | 5:00 is accepted |
| 4 | WAV of 300.999 s → accepted | Boundary tolerance works |
| 5 | WAV of 301.000 s → `[tooLong]` | Over the limit is rejected |
| 6 | 6-min FLAC and MP3 → `[tooLong]` | Length rule works on compressed formats |
| 7 | 6-min `.caf` → `[unsupportedFormat, tooLong]` | **Both** errors reported |
| 8 | Corrupt `.mp3` → `[unreadable]` | Damaged files are caught |
| 9 | Rejected file → nothing written to `Imports/` | Validation happens before copy |
| 10 | Import A then B → only B's copy remains | Old copy is replaced |
| 11 | `tooLong` message contains "5 minutes" and comes from the constant | Message matches the limit |

**ViewModel tests:**
- A file breaking both rules → both messages exposed, no song.
- Song A imported, then a rejected file → song A still loaded **and** the errors
  shown.
- Song A imported, then good song B → B loaded, errors cleared.

Each test will be checked to **fail** when its rule is broken (e.g. tighten the
boundary to `< 300` and confirm test 3 fails; make validation stop at the first
error and confirm test 7 fails).

**Manual check:** the Files picker can't be driven reliably by UI tests, so
pick real files in the simulator by hand: a good song, an unsupported audio
file, and confirm non-audio files are greyed out.

## Out of scope

- Playback, effects, waveform, export (later specs)
- A library of multiple imported songs
- Extracting audio from video files (`.mp4`, `.mov`)
- Detecting damage beyond the file header

## Decisions log

| Question | Decision |
|---|---|
| Picker filter | Audio files only (`[.audio]`) |
| Corrupt files | One "couldn't be read" message; save failures get their own message |
| Boundary | Accept under 5:01 (anything a player displays as "5:00" or less) |
| One song or many | One; a new import replaces the old |
| Length error text | States the limit only: "Only songs 5 minutes or shorter are accepted." |
| Rejected import with a song loaded | Keep the old song, show the errors |
