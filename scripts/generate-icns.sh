#!/usr/bin/env bash
# generate-icns.sh — Convert Assets/AppIcon.svg to AppIcon.icns
#
# Why this implementation:
# - Avoids swiftc toolchain/SDK mismatch issues in some environments.
# - Uses rsvg-convert (or qlmanage fallback) to rasterize SVG.
# - Uses Python Pillow to write a multi-size .icns directly.
#
# Usage:
#   ./scripts/generate-icns.sh
#
# Output:
#   Sources/SkillStudio/Resources/AppIcon.icns

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SVG_FILE="$PROJECT_ROOT/Assets/AppIcon.svg"
OUTPUT_ICNS="$PROJECT_ROOT/Sources/SkillStudio/Resources/AppIcon.icns"
TMP_ROOT="$(mktemp -d)"
PNG_1024="$TMP_ROOT/icon_1024x1024.png"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

if [ ! -f "$SVG_FILE" ]; then
  echo "Error: SVG file not found: $SVG_FILE"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 not found."
  exit 1
fi

echo "Generating 1024x1024 PNG from SVG ..."

# Preferred: librsvg renderer (more deterministic in CLI environments).
if command -v rsvg-convert >/dev/null 2>&1; then
  rsvg-convert -w 1024 -h 1024 "$SVG_FILE" -o "$PNG_1024"
# Fallback: QuickLook thumbnail generator (macOS builtin).
elif command -v qlmanage >/dev/null 2>&1; then
  qlmanage -t -s 1024 -o "$TMP_ROOT" "$SVG_FILE" >/dev/null 2>&1
  mv "$TMP_ROOT/AppIcon.svg.png" "$PNG_1024"
else
  echo "Error: neither rsvg-convert nor qlmanage is available."
  echo "Install librsvg (brew install librsvg) or use macOS qlmanage."
  exit 1
fi

echo "Creating .icns at $OUTPUT_ICNS ..."

python3 - "$PNG_1024" "$OUTPUT_ICNS" << 'PYEOF'
import sys
from PIL import Image

png_file = sys.argv[1]
output_icns = sys.argv[2]

image = Image.open(png_file).convert("RGBA")

# Common macOS icon representations embedded in the output .icns.
sizes = [
    (16, 16),
    (32, 32),
    (64, 64),
    (128, 128),
    (256, 256),
    (512, 512),
    (1024, 1024),
]

image.save(output_icns, format="ICNS", sizes=sizes)
print(f"Done: {output_icns}")
PYEOF

echo "File size: $(du -h "$OUTPUT_ICNS" | cut -f1)"
