#!/usr/bin/env bash
# Build a universal (fat) release APK for phones + emulators (all ABIs).
# Do not pass --target-platform or --split-per-abi — that is intentional.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
OUT_DIR="$ROOT/apks"
STAMP="$(date +%Y%m%d)"

cd "$APP"
VERSION_LINE="$(grep -E '^version:' pubspec.yaml | head -1)"
# e.g. 1.0.0+69 → build number 69
BUILD_NUM="${VERSION_LINE##*+}"
BUILD_NUM="${BUILD_NUM%%[[:space:]]*}"

echo "Building universal release APK (build $BUILD_NUM)…"
flutter build apk --release --dart-define=MW_BUILD="$BUILD_NUM"

SRC="$APP/build/app/outputs/flutter-apk/app-release.apk"
mkdir -p "$OUT_DIR"
DEST="$OUT_DIR/MatchWord-v${BUILD_NUM}Universal-${STAMP}.apk"
cp -f "$SRC" "$DEST"
ls -lh "$DEST"
echo "Universal APK ready: $DEST"
