#!/bin/sh
# Populate a wasm web bundle/ after an Emscripten build (emmake make).
# Run from anywhere; the script lives under the source tree.
#
# Usage: pack-wasm-bundle.sh [DEST_NAME_OR_ABS] [BUILD_DIR]
#   DEST: bundle directory name under the source root (default: wasm-web-bundle),
#         or an absolute path for the output directory.
#   BUILD_DIR: directory that contains built ivl, vvp, driver/, vpi/, tgt-*/
#              (default: same as the source root — in-tree build).
# Example (dylink in-tree):  pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic
# Example (out-of-tree):     pack-wasm-bundle.sh wasm-web-bundle_icarus_static /path/to/build-icarus-static-oz
#
# Optional: append lines to SOURCE_REVISION.txt from env WASM_SOURCE_REVISION_EXTRAS

set -e
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
BUILD=${2:-"$REPO"}
case "$1" in
  "") OUT_NAME=wasm-web-bundle; OUT=$REPO/wasm-web-bundle ;;
  /*) OUT=$1; OUT_NAME=$(basename "$1") ;;
  *) OUT_NAME=$1; OUT=$REPO/$1 ;;
esac
mkdir -p "$OUT/bin" "$OUT/lib/ivl/include"

for pair in \
  "driver/iverilog" \
  "ivl" \
  "ivlpp/ivlpp" \
  "vvp/vvp" \
  "vhdlpp/vhdlpp"
do
  base="$BUILD/$pair"
  if test ! -f "$base" || test ! -f "$base.wasm"; then
    echo "Missing $base or $base.wasm — build first (e.g. emmake make from BUILD_DIR; use BUILD_DIR as 2nd arg for out-of-tree)." >&2
    exit 1
  fi
  bn=$(basename "$pair")
  cp "$base" "$OUT/bin/$bn"
  cp "$base.wasm" "$OUT/bin/$bn.wasm"
done

for d in tgt-null tgt-stub tgt-vvp tgt-vhdl tgt-vlog95 tgt-pcb tgt-blif tgt-sizer; do
  for f in "$BUILD/$d"/*.tgt "$BUILD/$d"/*.conf; do
    if test -f "$f"; then cp "$f" "$OUT/lib/ivl/"; fi
  done
done

for f in "$BUILD/vpi"/*.vpi; do
  if test -f "$f"; then cp "$f" "$OUT/lib/ivl/"; fi
done

# Emscripten may emit companion *.wasm next to some side module names; copy any.
for f in "$BUILD/vpi"/*.wasm "$BUILD"/tgt-*/*.wasm; do
  if test -f "$f"; then cp "$f" "$OUT/lib/ivl/"; fi
done

cp "$REPO/constants.vams" "$REPO/disciplines.vams" "$OUT/lib/ivl/include/"

# GPL: pin exact corresponding source revision (from the source repo checkout).
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
    echo "BUNDLE_NAME=$OUT_NAME"
  ) >"$REV_FILE"
else
  {
    echo "REPO_URL=https://github.com/semisgdh/iverilog-wasm"
    echo "BRANCH=wasm-port"
    echo "GIT_COMMIT=unknown"
    echo "BUNDLE_NAME=$OUT_NAME"
    echo "# No Git checkout or git(1) missing; record SHA manually for GPL corresponding source."
  } >"$REV_FILE"
fi
if test -n "${WASM_SOURCE_REVISION_EXTRAS-}"; then
  printf '%s\n' "$WASM_SOURCE_REVISION_EXTRAS" >>"$REV_FILE"
fi

if test -f "$REPO/docs/CORRESPONDING_SOURCE.md"; then
  cp "$REPO/docs/CORRESPONDING_SOURCE.md" "$OUT/CORRESPONDING_SOURCE.md"
fi

echo "Packed $OUT"
