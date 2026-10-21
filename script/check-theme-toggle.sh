#!/usr/bin/env bash
# Every public layout must ship theme init + toggle JS (home/about use minima base, posts use default).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="${SITE_DIR:-$ROOT/_site}"

if [[ ! -d "$SITE" ]]; then
  echo "check-theme-toggle: missing build output at $SITE (run jekyll build first)" >&2
  exit 1
fi

check_page() {
  local file="$1"
  local label="$2"

  if [[ ! -f "$file" ]]; then
    echo "check-theme-toggle: $label not found at $file" >&2
    return 1
  fi

  local missing=0
  if ! grep -q 'id="theme-toggle"' "$file"; then
    echo "check-theme-toggle: $label missing #theme-toggle" >&2
    missing=1
  fi
  if ! grep -q 'theme-toggle\.js' "$file"; then
    echo "check-theme-toggle: $label missing theme-toggle.js" >&2
    missing=1
  fi
  if ! grep -q '__aioueResolveTheme' "$file"; then
    echo "check-theme-toggle: $label missing theme-init (__aioueResolveTheme)" >&2
    missing=1
  fi
  return "$missing"
}

fail=0
check_page "$SITE/index.html" "homepage" || fail=1
check_page "$SITE/about/index.html" "about" || fail=1

post_html="$(find "$SITE" -type f -path '*/2026/*/index.html' 2>/dev/null | head -1 || true)"
if [[ -z "$post_html" ]]; then
  echo "check-theme-toggle: no sample post under _site/2026/" >&2
  fail=1
else
  check_page "$post_html" "sample post ($(basename "$(dirname "$post_html")"))" || fail=1
fi

# Footer is the single hook that loads toggle JS on minima base layouts.
if ! grep -q 'theme-toggle\.html' "$ROOT/_includes/footer.html"; then
  echo "check-theme-toggle: footer.html must include theme-toggle.html" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "check-theme-toggle: ok"
