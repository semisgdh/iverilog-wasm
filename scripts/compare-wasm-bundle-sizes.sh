#!/bin/sh
# Print total size of *.wasm in listed bundle directories (bytes and human).
# Usage: compare-wasm-bundle-sizes.sh [DIR ...]
# Default: wasm-web-bundle_icarus_dynamic wasm-web-bundle_icarus_static (under repo root)

set -e
REPO=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
if test -n "$1"; then
  DIRS=$*
else
  DIRS="$REPO/wasm-web-bundle_icarus_dynamic $REPO/wasm-web-bundle_icarus_static"
fi

sum_wasm() {
  d=$1
  if test ! -d "$d"; then
    echo "MISSING: $d"
    return
  fi
  find "$d" -name '*.wasm' -type f -print0 2>/dev/null | xargs -0 -r stat -c %s 2>/dev/null | awk '{s+=$1} END{print s+0}'
}

printf '%s\n' "Directory (all *.wasm total bytes):"
any=0
for d in $DIRS; do
  s=$(sum_wasm "$d")
  if test "$s" = "" || test "$s" -eq 0 2>/dev/null; then
    continue
  fi
  any=1
  base=$(basename "$d")
  printf '  %s: %s' "$base" "$s"
  if command -v numfmt >/dev/null 2>&1; then
    printf ' (%s)' "$(numfmt --to=iec-i --suffix=B "$s" 2>/dev/null || echo "bytes")"
  fi
  printf '\n'
done
if test "$any" = 0; then
  echo "No .wasm files found. Build and pack first." >&2
  exit 1
fi
first=$(echo "$DIRS" | awk '{print $1}')
second=$(echo "$DIRS" | awk '{print $2}')
if test -d "$first" && test -d "$second"; then
  a=$(sum_wasm "$first")
  b=$(sum_wasm "$second")
  if test -n "$a" && test -n "$b" && test "$a" -gt 0 2>/dev/null; then
    saved=$((a - b))
    pct_saved=$((100 * saved / a))
    pct_rel=$((100 * b / a))
    printf '\n'
    printf "%s total wasm: %s bytes; %s total wasm: %s bytes.\n" \
      "$(basename "$first")" "$a" "$(basename "$second")" "$b"
    printf "Difference: %s bytes smaller for %s (~%s%% byte reduction vs %s; second is ~%s%% the size of first).\n" \
      "$saved" "$(basename "$second")" "$pct_saved" "$(basename "$first")" "$pct_rel"
  fi
fi
