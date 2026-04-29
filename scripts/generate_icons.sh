#!/usr/bin/env bash
# Generates the AutoChoice 1024x1024 App Icon PNG into the Asset Catalog.
# On macOS (CI), uses a Swift script that draws via CoreGraphics for a real
# branded look (gradient + 6-segment wheel + pointer).
# On Windows/Linux dev machines, falls back to ImageMagick if available, or
# skips silently — production builds always run on macOS, so the real asset
# is regenerated each CI run.

set -euo pipefail

APP_DIR="AutoChoice"
OUT_DIR="$APP_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUT_DIR"

if command -v swift >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
    swift scripts/IconGenerator.swift "$OUT_DIR/icon.png"
elif command -v convert >/dev/null 2>&1; then
    LETTER="A"
    GRAD_FROM="#FF006E"
    GRAD_TO="#3A86FF"
    convert -size 1024x1024 \
      -define gradient:angle=135 \
      gradient:"${GRAD_FROM}-${GRAD_TO}" \
      -alpha off \
      -fill white \
      -font Helvetica-Bold \
      -pointsize 600 -gravity center \
      -annotate +0+0 "$LETTER" \
      "$OUT_DIR/icon.png"
else
    echo "[generate_icons] Neither swift (macOS) nor imagemagick found — skipping."
    exit 0
fi

cat > "$OUT_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "[generate_icons] wrote $OUT_DIR/icon.png"
