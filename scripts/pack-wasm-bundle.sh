#!/bin/sh
# Populate wasm-web-bundle/ after an Emscripten build (emmake make).
# Run from anywhere; uses repository root containing this script.

set -e
REPO=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT="$REPO/wasm-web-bundle"
mkdir -p "$OUT/bin" "$OUT/lib/ivl/include"

for pair in \
  "driver/iverilog" \
  "ivl" \
  "ivlpp/ivlpp" \
  "vvp/vvp" \
  "vhdlpp/vhdlpp"
do
  base="$REPO/$pair"
  if test ! -f "$base" || test ! -f "$base.wasm"; then
    echo "Missing $base or $base.wasm — run emmake make from $REPO first." >&2
    exit 1
  fi
  bn=$(basename "$pair")
  cp "$base" "$OUT/bin/$bn"
  cp "$base.wasm" "$OUT/bin/$bn.wasm"
done

for d in tgt-null tgt-stub tgt-vvp tgt-vhdl tgt-vlog95 tgt-pcb tgt-blif tgt-sizer; do
  for f in "$REPO/$d"/*.tgt "$REPO/$d"/*.conf; do
    if test -f "$f"; then cp "$f" "$OUT/lib/ivl/"; fi
  done
done

for f in "$REPO/vpi"/*.vpi; do
  if test -f "$f"; then cp "$f" "$OUT/lib/ivl/"; fi
done

cp "$REPO/constants.vams" "$REPO/disciplines.vams" "$OUT/lib/ivl/include/"

echo "Packed $OUT (see wasm-web-bundle/README.txt)."
