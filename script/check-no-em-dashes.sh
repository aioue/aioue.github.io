#!/usr/bin/env bash
# Fail if _posts/ contain Unicode em-dashes (U+2014). Use ASCII hyphen instead.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

shopt -s globstar nullglob
files=(_posts/*.{md,markdown})

if [[ ${#files[@]} -eq 0 ]]; then
  exit 0
fi

if matches="$(grep -n $'—' "${files[@]}" 2>/dev/null || true)" && [[ -n "${matches}" ]]; then
  echo "ERROR: em-dashes (—) found in blog posts; use ASCII hyphen (-) instead:" >&2
  echo "${matches}" >&2
  exit 1
fi
