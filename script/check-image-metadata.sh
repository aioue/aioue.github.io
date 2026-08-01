#!/usr/bin/env bash
# Fail if images under ext/ contain EXIF/XMP/IPTC/GPS/ICC or other embedded metadata.
# Requires: exiftool (libimage-exiftool-perl / Image-ExifTool)
#
# Usage:
#   ./script/check-image-metadata.sh              # all images under ext/
#   ./script/check-image-metadata.sh path/to.jpg  # specific file(s)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if ! command -v exiftool >/dev/null 2>&1; then
  echo "ERROR: exiftool not found (install libimage-exiftool-perl or Image-ExifTool)" >&2
  exit 1
fi

# Tag groups that must be empty (privacy / publishing policy).
METADATA_ARGS=(
  -EXIF:All
  -XMP:All
  -IPTC:All
  -GPS:All
  -ICC_Profile:All
  -Photoshop:All
  -MakerNotes:All
  -JFIF:All
  -PNG:TextualData
  -PNG:Parameters
)

check_file() {
  local file="$1"
  local meta
  meta="$(exiftool -s -s -s "${METADATA_ARGS[@]}" "$file" 2>/dev/null | grep -v '^$' || true)"
  if [[ -n "$meta" ]]; then
    echo "ERROR: embedded metadata in ${file}:" >&2
    exiftool -a -G1 "${METADATA_ARGS[@]}" "$file" >&2
    echo "  Strip with: ./script/strip-image-metadata.sh ${file}" >&2
    return 1
  fi
  return 0
}

errors=0

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  mapfile -t files < <(find ext -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o \
    -iname '*.gif' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.heic' -o \
    -iname '*.avif' \) | sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No images to check."
  exit 0
fi

for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue
  check_file "$file" || errors=$((errors + 1))
done

if (( errors > 0 )); then
  echo "Image metadata check failed (${errors} file(s)). Remove metadata before commit/push." >&2
  exit 1
fi

echo "Image metadata check passed (${#files[@]} file(s))."
