#!/bin/sh
# Populate wasm-web-bundle/ after an Emscripten build (emmake make).
# Run from anywhere; uses repository root containing this script.
#
# Usage: pack-wasm-bundle.sh [DEST_DIR]
#   Default DEST_DIR: wasm-web-bundle
#   Example (dylink build): pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic

set -e
REPO=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT=${1:-"$REPO/wasm-web-bundle"}
case "$OUT" in
  /*) ;;
  *) OUT="$REPO/$OUT" ;;
esac
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

# Emscripten may emit companion *.wasm next to some side module names; copy any.
for f in "$REPO/vpi"/*.wasm "$REPO"/tgt-*/*.wasm; do
  if test -f "$f"; then cp "$f" "$OUT/lib/ivl/"; fi
done

cp "$REPO/constants.vams" "$REPO/disciplines.vams" "$OUT/lib/ivl/include/"

# GPL: pin exact corresponding source revision inside the bundle (copy-paste friendly).
REV_FILE="$OUT/SOURCE_REVISION.txt"
if test -d "$REPO/.git" && command -v git >/dev/null 2>&1; then
  (
    cd "$REPO" || exit 1
    echo "REPO_URL=https://github.com/semisgdh/iverilog-wasm"
    echo "BRANCH=wasm-port"
    echo "GIT_COMMIT=$(git rev-parse HEAD)"
    echo "GIT_COMMIT_SHORT=$(git rev-parse --short HEAD)"
    echo "GIT_COMMIT_DATE=$(git log -1 --format=%ci HEAD)"
    br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) && echo "GIT_CHECKOUT_BRANCH=$br"
    tag=$(git describe --tags --exact-match HEAD 2>/dev/null) && echo "GIT_TAG_EXACT=$tag"
  ) >"$REV_FILE"
else
  {
    echo "REPO_URL=https://github.com/semisgdh/iverilog-wasm"
    echo "BRANCH=wasm-port"
    echo "GIT_COMMIT=unknown"
    echo "# Pack was run without a Git checkout or without git(1); record SHA manually for GPL corresponding source."
  } >"$REV_FILE"
fi

if test -f "$REPO/docs/CORRESPONDING_SOURCE.md"; then
  cp "$REPO/docs/CORRESPONDING_SOURCE.md" "$OUT/CORRESPONDING_SOURCE.md"
fi

echo "Packed $OUT"
