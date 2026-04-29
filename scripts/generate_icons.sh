#!/usr/bin/env bash
# Generates a 1024x1024 App Icon PNG into the Asset Catalog.
# Placeholder — gradient + initial letter. Designed to be replaced with a real
# brand asset later (just drop a real icon.png into the same path).
#
# Usage:
#   bash scripts/generate_icons.sh
#
# Idempotent: re-runs overwrite the existing icon.

set -euo pipefail

APP_DIR="AutoChoice"
LETTER="A"
GRAD_FROM="#FF006E"
GRAD_TO="#3A86FF"

OUT_DIR="$APP_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUT_DIR"

if ! command -v convert >/dev/null 2>&1; then
  echo "[generate_icons] ImageMagick (convert) not found — skipping icon generation."
  echo "[generate_icons] Install via: brew install imagemagick"
  exit 0
fi

# Pick a font that exists on macOS by default.
if convert -list font 2>/dev/null | grep -qE '^\s+Font: Helvetica-Bold'; then
  FONT="Helvetica-Bold"
elif convert -list font 2>/dev/null | grep -qE '^\s+Font: Helvetica'; then
  FONT="Helvetica"
else
  FONT="Arial-Bold"
fi

convert -size 1024x1024 \
  -define gradient:angle=135 \
  gradient:"${GRAD_FROM}-${GRAD_TO}" \
  -alpha off \
  -fill white \
  -font "$FONT" \
  -pointsize 600 -gravity center \
  -annotate +0+0 "$LETTER" \
  "$OUT_DIR/icon.png"

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

echo "[generate_icons] wrote $OUT_DIR/icon.png ($(file -b --mime-type "$OUT_DIR/icon.png" 2>/dev/null || echo png))"
