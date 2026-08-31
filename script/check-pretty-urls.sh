#!/usr/bin/env bash
# Verify Jekyll permalink:pretty output and no stale .html post URLs in content.
# Run after: bundle exec jekyll build
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

errors=0

shopt -s nullglob
for post in _posts/*.{md,markdown}; do
  [[ -f "${post}" ]] || continue
  basename=$(basename "${post}")
  if [[ ! "${basename}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})-(.+)\.(md|markdown)$ ]]; then
    echo "WARN: skipping unexpected post filename: ${basename}" >&2
    continue
  fi
  y="${BASH_REMATCH[1]}"
  m="${BASH_REMATCH[2]}"
  d="${BASH_REMATCH[3]}"
  slug="${BASH_REMATCH[4]}"
  expected="_site/${y}/${m}/${d}/${slug}/index.html"
  legacy="_site/${y}/${m}/${d}/${slug}.html"

  if [[ ! -f "${expected}" ]]; then
    echo "ERROR: missing pretty permalink output: ${expected} (from ${basename})" >&2
    errors=$((errors + 1))
  fi
  if [[ -f "${legacy}" ]]; then
    echo "ERROR: legacy .html output exists; permalink:pretty should use a directory: ${legacy}" >&2
    errors=$((errors + 1))
  fi
done

# Internal blog links must use trailing-slash pretty URLs, not .html
while IFS= read -r match; do
  [[ -z "${match}" ]] && continue
  echo "ERROR: ${match}" >&2
  errors=$((errors + 1))
done < <(grep -RInE 'aioue\.(net|github\.io)/[0-9]{4}/[0-9]{2}/[0-9]{2}/[^)"'\''[:space:]]+\.html' \
  _posts README.md about.markdown index.markdown 2>/dev/null || true)

if (( errors > 0 )); then
  echo "Pretty URL checks failed (${errors} error(s))" >&2
  exit 1
fi

echo "Pretty URL checks passed."
