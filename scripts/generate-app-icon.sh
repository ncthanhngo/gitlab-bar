#!/usr/bin/env bash
# Rasterises the SVG icon sources into the AppIcon asset catalog.
# Requires rsvg-convert (brew install librsvg).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
resources="$repo_root/GitLabBar/Resources"
iconset="$resources/Assets.xcassets/AppIcon.appiconset"

full_svg="$resources/AppIcon.svg"
small_svg="$resources/AppIcon-small.svg"

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found: brew install librsvg" >&2; exit 1; }

mkdir -p "$iconset"

# 16pt and 32pt slots use the simplified glyph so it stays readable when tiny.
render() {
  local px="$1" out="$2" src="$3"
  rsvg-convert -w "$px" -h "$px" "$src" -o "$iconset/$out"
  echo "  $out (${px}px)"
}

echo "Rendering AppIcon.appiconset:"
render 16   icon_16x16.png       "$small_svg"
render 32   icon_16x16@2x.png    "$small_svg"
render 32   icon_32x32.png       "$small_svg"
render 64   icon_32x32@2x.png    "$small_svg"
render 128  icon_128x128.png     "$full_svg"
render 256  icon_128x128@2x.png  "$full_svg"
render 256  icon_256x256.png     "$full_svg"
render 512  icon_256x256@2x.png  "$full_svg"
render 512  icon_512x512.png     "$full_svg"
render 1024 icon_512x512@2x.png  "$full_svg"

echo "Done."
