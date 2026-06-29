#!/usr/bin/env bash
# Builds a double-clickable Opus2Wav.app from the SwiftPM package — no Xcode.
#
#   ./scripts/build-app.sh
#   open ./Opus2Wav.app          # or move it to /Applications and double-click
#
# The app is ad-hoc signed and NOT sandboxed, so it launches locally without
# Gatekeeper friction and can use a system ffmpeg (brew install ffmpeg). For a
# sandboxed, distributable build signed with a Developer ID, use
# scripts/codesign-bundle.sh instead.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Opus2Wav"
CONFIG="${CONFIG:-release}"
APP_DIR="$ROOT/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This builds a macOS .app and must be run on macOS." >&2
    exit 1
fi

echo "Building ($CONFIG)…"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -x "$BIN" ]]; then
    echo "Build did not produce an executable at: $BIN" >&2
    exit 1
fi

echo "Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN" "$MACOS_DIR/$APP_NAME"
cp "$ROOT/App/Info.plist" "$CONTENTS/Info.plist"

# Embed ffmpeg if a static binary was fetched; otherwise the app auto-discovers
# a system ffmpeg (Homebrew / MacPorts / PATH) at runtime.
if [[ -x "$ROOT/Sources/Opus2Wav/Resources/ffmpeg" ]]; then
    echo "Embedding bundled ffmpeg…"
    cp "$ROOT/Sources/Opus2Wav/Resources/ffmpeg" "$RES_DIR/ffmpeg"
    chmod +x "$RES_DIR/ffmpeg"
    codesign --force --sign - "$RES_DIR/ffmpeg" 2>/dev/null || true
else
    echo "No bundled ffmpeg found — the app will use a system ffmpeg at runtime."
    echo "  (install one with: brew install ffmpeg)"
fi

echo "Ad-hoc signing the app…"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo
echo "Done: $APP_DIR"
echo "Launch it with:   open \"$APP_DIR\""
echo "Or drag $APP_NAME.app into /Applications and double-click it."
