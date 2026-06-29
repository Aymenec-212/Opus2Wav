#!/usr/bin/env bash
# Fetches a static, universal (arm64+x86_64) ffmpeg binary and places it in
# Sources/Opus2Wav/Resources/ffmpeg ready for bundling.
#
# Static builds from https://www.osxexperts.net (Helmut K. C. Tessarek) ship
# arm64 and x86_64 archives separately; we download both and lipo them into a
# universal binary. The exact upstream URL changes per release — pin one and
# update as needed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$ROOT/Sources/Opus2Wav/Resources"
DEST="$DEST_DIR/ffmpeg"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

ARM64_URL="${OPUS2WAV_FFMPEG_ARM64_URL:-}"
X86_64_URL="${OPUS2WAV_FFMPEG_X86_64_URL:-}"

if [[ -z "$ARM64_URL" || -z "$X86_64_URL" ]]; then
    cat >&2 <<'EOM'
Set the upstream archive URLs explicitly, e.g.:

    OPUS2WAV_FFMPEG_ARM64_URL=https://.../ffmpeg-N-arm64-static.zip \
    OPUS2WAV_FFMPEG_X86_64_URL=https://.../ffmpeg-N-x86_64-static.zip \
    ./scripts/fetch-ffmpeg.sh

The build URLs change per release; pin a specific version and verify its
checksum before bundling. Suggested source: https://www.osxexperts.net
EOM
    exit 1
fi

mkdir -p "$DEST_DIR"

fetch() {
    local url="$1" out="$2"
    echo "Fetching $url"
    curl --fail --location --silent --show-error --output "$out" "$url"
}

extract_ffmpeg() {
    local archive="$1" out="$2"
    case "$archive" in
        *.zip)  unzip -p "$archive" '*/ffmpeg' > "$out" 2>/dev/null \
                || unzip -p "$archive" ffmpeg > "$out" ;;
        *.7z)   7z x -so "$archive" ffmpeg > "$out" ;;
        *.tar.xz) tar -xJOf "$archive" --wildcards '*ffmpeg' > "$out" ;;
        *) echo "Unsupported archive: $archive" >&2; exit 2 ;;
    esac
    chmod +x "$out"
}

fetch "$ARM64_URL"  "$WORK_DIR/ffmpeg-arm64.archive"
fetch "$X86_64_URL" "$WORK_DIR/ffmpeg-x86_64.archive"

extract_ffmpeg "$WORK_DIR/ffmpeg-arm64.archive"  "$WORK_DIR/ffmpeg-arm64"
extract_ffmpeg "$WORK_DIR/ffmpeg-x86_64.archive" "$WORK_DIR/ffmpeg-x86_64"

lipo -create -output "$DEST" \
    "$WORK_DIR/ffmpeg-arm64" \
    "$WORK_DIR/ffmpeg-x86_64"

xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true
chmod +x "$DEST"

echo "Universal ffmpeg installed: $DEST"
lipo -info "$DEST"
