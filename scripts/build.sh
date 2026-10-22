#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
require_macos
DEST_DIR="${1:-$ROOT/dist}"
mkdir -p "$DEST_DIR" "$ROOT/.build"
DEST_DIR="$(cd "$DEST_DIR" && pwd)"
SCRATCH="$(mktemp -d "$ROOT/.build/compile.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
configure_swift "$SCRATCH"

for ARCH in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -target "${ARCH}-apple-macosx12.0" \
        ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} \
        -module-cache-path "$ROOT/.build/cache-$ARCH" \
        "$ROOT/Sources/ImageRenamer/RenameEngine.swift" \
        "$ROOT/Sources/ImageRenamer/main.swift" \
        -o "$SCRATCH/ImageRenamer-$ARCH"
done

APP="$DEST_DIR/逐图改名.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun lipo -create "$SCRATCH/ImageRenamer-arm64" "$SCRATCH/ImageRenamer-x86_64" \
    -output "$APP/Contents/MacOS/ImageRenamer"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
xcrun lipo "$APP/Contents/MacOS/ImageRenamer" -verify_arch arm64 x86_64
echo "已构建：$APP"
