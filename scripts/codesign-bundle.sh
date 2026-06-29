#!/usr/bin/env bash
# Codesigns the embedded ffmpeg binary and (optionally) the parent .app bundle
# with matching credentials. Run after building, before notarization/distribution.
#
# Usage:
#   IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   APP_BUNDLE=build/Opus2Wav.app \
#   ./scripts/codesign-bundle.sh
#
# For local development (unsigned ad-hoc), set IDENTITY=- .

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTITLEMENTS="$ROOT/App/Opus2Wav.entitlements"
IDENTITY="${IDENTITY:-}"
APP_BUNDLE="${APP_BUNDLE:-}"

if [[ -z "$IDENTITY" ]]; then
    echo "Set IDENTITY (e.g. 'Developer ID Application: ...' or '-' for ad-hoc)" >&2
    exit 1
fi

if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
    echo "Set APP_BUNDLE to the built .app bundle path" >&2
    exit 1
fi

FFMPEG_BIN="$APP_BUNDLE/Contents/Resources/ffmpeg"
if [[ ! -f "$FFMPEG_BIN" ]]; then
    echo "Bundled ffmpeg binary not found at: $FFMPEG_BIN" >&2
    exit 1
fi

xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

echo "Signing embedded ffmpeg…"
codesign --force --sign "$IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    --timestamp \
    "$FFMPEG_BIN"

echo "Signing app bundle…"
codesign --force --sign "$IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE"

echo "Verifying…"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl --assess --type execute --verbose=2 "$APP_BUNDLE" || true

echo "Signed: $APP_BUNDLE"
