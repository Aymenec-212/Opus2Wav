# Embedded ffmpeg binary

The bundled static `ffmpeg` binary is **not checked into version control**.
Place a universal (arm64 + x86_64), statically linked Mach-O executable at:

    Sources/Opus2Wav/Resources/ffmpeg

The simplest path is:

    ./scripts/fetch-ffmpeg.sh

which downloads and `lipo`-merges the two architecture slices. See the script
header for the upstream URL environment variables.

This directory is excluded from the SwiftPM target (see `Package.swift`), so
dropping the binary here will not break `swift build` / `swift run`.
`FFmpegRunner.locateBundledBinary()` finds it directly on disk via the
`Sources/Opus2Wav/Resources/ffmpeg` dev path. When wrapped in an Xcode app
target, instead add the binary to **Copy Bundle Resources** so it resolves via
`Bundle.main`.

> For just converting files locally you usually don't need this at all — an
> ffmpeg on your `PATH` (e.g. `brew install ffmpeg`) is auto-discovered.

For distribution: see `scripts/codesign-bundle.sh`.
