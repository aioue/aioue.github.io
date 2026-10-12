#!/usr/bin/env bash
# Fail if a post's last git commit is after its publish date but front matter lacks
# last_modified_at, or if last_modified_at is older than that commit.
# When editing post body text, bump last_modified_at to today before commit (see AGENTS.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
shopt -s nullglob

fail=0

for path in _posts/*.md; do
  [[ -f "$path" ]] || continue
  pub="$(python3 - "$path" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
m = re.search(r"^date:\s*'([^']+)'", text, re.M)
print(m.group(1)[:10] if m else sys.argv[1].split("/")[-1][:10])
PY
)"
  last="$(git log -1 --format=%ci -- "$path" 2>/dev/null | cut -c1-10)"
  [[ -n "$last" ]] || continue

  lm_line="$(grep -E '^last_modified_at:' "$path" 2>/dev/null || true)"
  if [[ "$last" > "$pub" ]]; then
    if [[ -z "$lm_line" ]]; then
      echo "ERROR: $path published $pub but last git commit $last; add last_modified_at to front matter" >&2
      fail=1
      continue
    fi
    lm="${lm_line#last_modified_at: }"
    lm="${lm//\'/}"
    lm="${lm//\"/}"
    if [[ "$lm" < "$last" ]]; then
      echo "ERROR: $path last_modified_at $lm is older than last git commit $last; bump it" >&2
      fail=1
    fi
  fi
done

exit "$fail"
