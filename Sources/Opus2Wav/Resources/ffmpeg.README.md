# Embedded ffmpeg binary

The bundled static `ffmpeg` binary is **not checked into version control**.
Place a universal (arm64 + x86_64), statically linked Mach-O executable at:

    Sources/Opus2Wav/Resources/ffmpeg

The simplest path is:

    ./scripts/fetch-ffmpeg.sh

which downloads and `lipo`-merges the two architecture slices. See the script
header for the upstream URL environment variables.

After bundling, the binary is loaded via `Bundle.module.url(forResource: "ffmpeg", withExtension: nil)`
(SwiftPM) or `Bundle.main.url(...)` (when wrapped in an Xcode app target with
the file added to `.app/Contents/Resources/`).

For distribution: see `scripts/codesign-bundle.sh`.
