#!/usr/bin/env bash
# Run binaryen wasm-opt on a packed Icarus WASM tree (dylink: .wasm, .vpi, .tgt).
# Emscripten output uses bulk memory + sign-ext + nontrapping float→int; wasm-opt
# defaults to MVP-only and will error without these --enable-* flags.
#
# Usage (from repo root):
#   ./scripts/wasm-opt-icarus-bundle.sh [--verify] [BUNDLE_DIR]
#   --verify  after opt: run check-icarus-dylink-exports.cjs on bin/ivl.wasm and bin/vvp.wasm
# Env:
#   WASM_OPT   path to wasm-opt (default: $HOME/emsdk/upstream/bin/wasm-opt, else PATH)
#   WASM_OPT_PASS  e.g. -Oz (default), or -O3, -Os
#
# Emscripten already runs some Binaryen; this is an extra pass on packed artifacts.
# Does not create backups; re-run pack from a build dir if you need originals.

set -e
REPO=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
VERIFY=0
if test "${1:-}" = "--verify"; then
  VERIFY=1
  shift
fi
BUNDLE=${1:-"$REPO/wasm-web-bundle_icarus_static"}
PASS=${WASM_OPT_PASS:--Oz}

WASM_OPT_BIN=${WASM_OPT:-"$HOME/emsdk/upstream/bin/wasm-opt"}
if test ! -x "$WASM_OPT_BIN" && command -v wasm-opt >/dev/null 2>&1; then
  WASM_OPT_BIN=$(command -v wasm-opt)
fi
if test ! -x "$WASM_OPT_BIN"; then
  echo "wasm-opt not found. Set WASM_OPT or install binaryen (e.g. emsdk upstream/bin)." >&2
  exit 1
fi

FEATURES="--enable-bulk-memory --enable-sign-ext --enable-nontrapping-float-to-int"

if test ! -d "$BUNDLE"; then
  echo "Not a directory: $BUNDLE" >&2
  exit 1
fi

sum_bytes() {
  find "$BUNDLE" -type f \( -name '*.wasm' -o -name '*.vpi' -o -name '*.tgt' \) -print0 |
    xargs -0 -r stat -c %s 2>/dev/null | awk '{s+=$1} END{print s+0}'
}

before=$(sum_bytes)
count=$(find "$BUNDLE" -type f \( -name '*.wasm' -o -name '*.vpi' -o -name '*.tgt' \) 2>/dev/null | wc -l)
ivl_w="$BUNDLE/bin/ivl.wasm"
vvp_w="$BUNDLE/bin/vvp.wasm"
if test -f "$ivl_w"; then before_ivl=$(stat -c%s "$ivl_w"); else before_ivl=0; fi
if test -f "$vvp_w"; then before_vvp=$(stat -c%s "$vvp_w"); else before_vvp=0; fi

echo "wasm-opt: $WASM_OPT_BIN ($($WASM_OPT_BIN --version 2>&1 | head -1))"
echo "bundle: $BUNDLE"
echo "files: $count  pass: $PASS $FEATURES"
echo "total bytes before: $before (bin/ivl.wasm: $before_ivl, bin/vvp.wasm: $before_vvp)"

find "$BUNDLE" -type f \( -name '*.wasm' -o -name '*.vpi' -o -name '*.tgt' \) -print0 |
  while IFS= read -r -d '' f; do
    t="$f.tmp.$$"
    "$WASM_OPT_BIN" $FEATURES $PASS "$f" -o "$t"
    mv "$t" "$f"
  done

after=$(sum_bytes)
saved=$((before - after))
if test "$before" -gt 0; then
  pct=$((100 * saved / before))
else
  pct=0
fi

after_ivl=0
after_vvp=0
test -f "$ivl_w" && after_ivl=$(stat -c%s "$ivl_w")
test -f "$vvp_w" && after_vvp=$(stat -c%s "$vvp_w")
echo "total bytes after:  $after (bin/ivl.wasm: $after_ivl, bin/vvp.wasm: $after_vvp)"
echo "saved: $saved bytes (~${pct}% of previous total; ivl: $((before_ivl - after_ivl)), vvp: $((before_vvp - after_vvp)))"

if test "$VERIFY" = 1; then
  chk="$REPO/scripts/check-icarus-dylink-exports.cjs"
  if test -f "$chk" && test -f "$ivl_w" && test -f "$vvp_w"; then
    echo "==> verify: node $chk ..."
    node "$chk" "$ivl_w" "$vvp_w"
  else
    echo "verify skipped (missing $chk or main modules)" >&2
  fi
fi
