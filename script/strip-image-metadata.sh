#!/usr/bin/env bash
# Strip embedded metadata from an image (writes alongside or to -o path).
# Requires: exiftool
#
# Usage:
#   ./script/strip-image-metadata.sh photo.jpg
#   ./script/strip-image-metadata.sh photo.heic -o ext/m5stack/photo.jpg

set -euo pipefail

if ! command -v exiftool >/dev/null 2>&1; then
  echo "error: exiftool not found (install libimage-exiftool-perl)" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <input> [-o output]" >&2
  exit 1
fi

src="$1"
shift
out=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$out" ]]; then
  base="${src%.*}"
  ext="${src##*.}"
  out="${base}-stripped.${ext}"
fi

mkdir -p "$(dirname "$out")"
exiftool -all= -o "$out" "$src"
echo "Wrote ${out}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"${ROOT}/script/check-image-metadata.sh" "$out"
