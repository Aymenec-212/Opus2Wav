# Opus2Wav — ASR Prep

Local, sandboxed macOS utility that batch-converts `.opus` files into
**16 kHz · Mono · 16-bit Linear PCM `.wav`** — the canonical ingestion
format for Whisper, Wav2Vec2, Qwen2-Audio, and similar ASR pipelines.

Pure on-device. No telemetry. No paywalls. No external dependencies once
the static `ffmpeg` binary is bundled.

---

## Architecture

Three isolated layers with strict unidirectional flow:

| Layer | Responsibility |
| --- | --- |
| **UI** (SwiftUI) | Drop zone, lazy task list, control bar — `@MainActor` `ObservableObject` state machine. |
| **Orchestration** | Capped `TaskGroup` (≤ `N − 1` cores), live `stderr` progress parsing, 60 s per-task watchdog. |
| **Execution** | Embedded static, universal `ffmpeg` Mach-O at `.app/Contents/Resources/ffmpeg`. |

```
ffmpeg -y -i <in.opus> -acodec pcm_s16le -ac 1 -ar 16000 <out.wav>
```

---

## Repository layout

```
Sources/Opus2Wav/
├── Opus2WavApp.swift             # entry point: branches to CLI or SwiftUI app
├── CLI/                          # CLIRunner — headless `--cli` conversion path
├── Models/                       # ConversionTask, ConversionStatus
├── Orchestration/                # FFmpegRunner, ConversionEngine, ProgressParser, FileDiscovery
├── UI/                           # ContentView, DropZoneView, TaskListView, TaskRowView, ControlBarView
└── Resources/
    ├── ffmpeg.README.md          # placeholder doc
    └── ffmpeg                    # universal static binary (NOT in git; fetched via scripts)
Tests/Opus2WavTests/              # XCTest cases for the parser & file discovery
App/
├── Info.plist                    # bundle metadata
└── Opus2Wav.entitlements         # sandbox + user-selected R/W + bookmark scope
scripts/
├── fetch-ffmpeg.sh               # lipo arm64 + x86_64 → universal binary
└── codesign-bundle.sh            # signs ffmpeg + .app with matching credentials
Package.swift                     # SwiftPM manifest (macOS 14+)
```

---

## Quickest local path (just convert some files)

On macOS, with [ffmpeg](https://ffmpeg.org) available anywhere standard:

```bash
brew install ffmpeg     # skip if you already have it
git clone <this repo> && cd Opus2Wav
```

### Option A — headless CLI (most reliable; no display needed)

```bash
# Convert a single file (writes next to the source):
swift run Opus2Wav --cli recording.opus

# Convert a whole folder (recursive) into a chosen output directory:
swift run Opus2Wav --cli ~/darija-corpus -o ~/wavs
```

Every input is converted to `16 kHz · mono · 16-bit PCM .wav`. Folders are
walked recursively for `.opus`; name collisions get a short unique suffix so
nothing is overwritten. Exit code is non-zero if any file fails. Run
`swift run Opus2Wav --cli --help` for all options. This path works over SSH
and in scripts/CI.

### Option B — GUI

```bash
swift run Opus2Wav
```

The window opens, you drag `.opus` files (or whole folders) onto the drop
zone, optionally pick an output folder, and hit **Start**. Converted
`16 kHz · mono · 16-bit PCM` `.wav` files land in your **Downloads** folder
by default.

No bundled binary required for this path: `FFmpegRunner.locateBundledBinary()`
auto-discovers ffmpeg in priority order —

1. `OPUS2WAV_FFMPEG=/abs/path/to/ffmpeg` (explicit override),
2. a binary bundled in the `.app` (`Bundle.main`),
3. `./Sources/Opus2Wav/Resources/ffmpeg` (the fetch script's output),
4. Homebrew / MacPorts / `/usr/bin` standard locations,
5. anything named `ffmpeg` on your `PATH`.

So `brew install ffmpeg` is enough to make `swift run` work end to end.

---

## Build (bundled / distributable)

### 1. Provision the embedded `ffmpeg`

```bash
OPUS2WAV_FFMPEG_ARM64_URL=https://…/ffmpeg-arm64-static.zip \
OPUS2WAV_FFMPEG_X86_64_URL=https://…/ffmpeg-x86_64-static.zip \
./scripts/fetch-ffmpeg.sh
```

Pin to a specific upstream release and verify the SHA-256 before bundling.
Builds from [osxexperts.net](https://www.osxexperts.net) and
[evermeet.cx/ffmpeg](https://evermeet.cx/ffmpeg/) are commonly used.

### 2. Ship a sandboxed `.app` (recommended for distribution)

Wrap the package in an Xcode macOS app target:

1. **File ▸ New ▸ Project ▸ macOS App** ("Opus2Wav", SwiftUI, Swift).
2. Replace Xcode's generated `App.swift` and `ContentView.swift` with the
   contents of `Sources/Opus2Wav/` (add all `.swift` files to the target).
3. Add `App/Info.plist` as the target's Info.plist.
4. Add `App/Opus2Wav.entitlements` under **Signing & Capabilities** and
   enable **App Sandbox**.
5. Add `Sources/Opus2Wav/Resources/ffmpeg` to **Copy Bundle Resources**.
6. Set deployment target to **macOS 14.0**.
7. Archive ▸ Distribute ▸ Developer ID, then run:

```bash
IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APP_BUNDLE=build/Opus2Wav.app \
./scripts/codesign-bundle.sh
```

For local ad-hoc signing during development, use `IDENTITY=-`.

---

## Test

```bash
swift test
```

XCTest covers the regex parser (`Duration:` / `time=` extraction across
HH:MM:SS.cs boundaries) and the file-discovery layer (recursive `.opus`
enumeration, case-insensitive matching, dedup, collision-safe destinations).

---

## Behaviour notes

- **Concurrency cap**: `max(1, ProcessInfo.processorCount - 1)` workers, so
  the WindowServer / SwiftUI render loop always retains a core.
- **Watchdog**: any single ffmpeg invocation that exceeds 60 s is
  `.terminate()`-ed and the task is marked `.failed`. Tune via
  `FFmpegRunner.perTaskTimeoutSeconds`.
- **Filename collisions**: output is `<base>.wav` unless that path already
  exists, in which case an 8-char UUID suffix is appended.
- **Folder drops**: recursive walk via `FileManager.enumerator` filtering
  case-insensitive `.opus`.
- **Sandbox**: every dropped URL is wrapped in
  `startAccessingSecurityScopedResource()` / `stop…` for the duration of
  the conversion.

---

## Roadmap markers

- [x] Phase 1 — Engine validation (static binary + subprocess + stderr parse)
- [x] Phase 2 — Core orchestration (`TaskGroup`, watchdog, progress)
- [x] Phase 3 — SwiftUI layer (drop zone, lazy list, control bar, sandbox)
