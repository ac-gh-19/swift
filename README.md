# MusicMod

An iOS app for turning any song into the kind of remixes popular on YouTube —
slowed + reverb, sped up / nightcore, lofi, and more.

## How it works

1. Import a song from the Files app.
2. Shape the sound with **sliders for each effect** — every effect is fully
   manual, so you can dial in exactly the sound you want:
   - **Speed** — slow down or speed up
   - **Pitch** — shift up or down
   - **Reverb** — amount of room/hall echo
   - **Lofi tone** — filter cutoff and grit for a warm, muffled sound
3. Or start from a **preset** (Slowed + Reverb, Nightcore, Lofi) — a preset just
   moves the sliders to a starting point, and you can keep tweaking from there.
4. Preview changes live, then export the result as a new audio file.

## Tech

Swift, SwiftUI, and Apple's built-in audio frameworks (AVFoundation /
AVAudioEngine, Accelerate). No third-party dependencies.

## Docs

- [`CLAUDE.md`](CLAUDE.md) — project rules, architecture, and workflow
- [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) — current status and changelog
