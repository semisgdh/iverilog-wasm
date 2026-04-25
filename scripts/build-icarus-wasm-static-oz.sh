#!/usr/bin/env bash
# Out-of-tree Emscripten build: WASM dylink ON, compile -Os -g0, link -O2 (no LTO).
# -Oz / -Oz -flto: LLVM has crashed on vvp/ (e.g. vthread, vvp_cobject).
# -O2 -flto: also crashes here (e.g. PExpr.cc in the optimizer) on some Clang 23 builds — not
#   just -Oz+LTO. Use non-LTO unless a future toolchain fixes it.
# Link -O2 (not -Os): LDFLAGS=-Os can break dylink re-exports for system.vpi.
# Rare: LLVM may segfault once on a random .cc under -Os — re-run; if it persists, use -O2 compile.
# Produces wasm-web-bundle_icarus_static/ — same dlopen/.vpi/.tgt model as
# wasm-web-bundle_icarus_dynamic, smaller than a typical -O2 -g in-tree build.
#
# Do NOT pass --disable-wasm-dylink here: browser runtimes that load
# lib/ivl/system.vpi and vvp.tgt require Emscripten dynamic linking.
#
# Removes stale *.o in source subdirs (VPATH) before configure; re-run in-tree
# emmake make to refresh wasm-web-bundle_icarus_dynamic if needed.
#
# Usage: from repo root, ./scripts/build-icarus-wasm-static-oz.sh
# Optional: EMSDK_EMCMAKE=/path/to/emscripten (default: $HOME/emsdk/upstream/emscripten)
# Optional: BUILD_DIR (default: $SRC_ROOT/build-icarus-oz-dylink)

set -euo pipefail
SRC_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BUILD_DIR=${BUILD_DIR:-"$SRC_ROOT/build-icarus-oz-dylink"}
EM_BIN=${EMSDK_EMCMAKE:-"$HOME/emsdk/upstream/emscripten"}
export PATH="$EM_BIN:$PATH"

if ! command -v emcc >/dev/null 2>&1; then
  echo "emcc not in PATH. Set EMSDK_EMCMAKE to your Emscripten directory." >&2
  exit 1
fi

LOG=$SRC_ROOT/wasm-web-bundle_icarus_static/BUILD_LOG.txt
# Truncate log at start of successful pack path; directory may not exist yet
mkdir -p "$SRC_ROOT/wasm-web-bundle_icarus_static"

{
  echo "=== iverilog-wasm compact-dylink bundle build log ==="
  date -u 2>/dev/null || date
  echo "SRC_ROOT=$SRC_ROOT"
  echo "BUILD_DIR=$BUILD_DIR"
  echo "emcc=$(command -v emcc)"
  emcc --version 2>&1 | head -3
  echo ""
  echo "Configure: emconfigure <src>/configure (no --disable-wasm-dylink; wasm dylink stays enabled for emcc)"
  echo "CFLAGS/CXXFLAGS: -Os -g0; LDFLAGS: -O2 (no -flto: LLVM can crash; see script header)"
  echo ""
} | tee "$LOG"

echo "==> Removing stale *.o in source subdirs (VPATH / out-of-tree safety)"
for d in . ivlpp vhdlpp vvp vpi tgt-null tgt-stub tgt-vvp tgt-vhdl tgt-vlog95 tgt-pcb tgt-blif tgt-sizer driver; do
  if test -d "$SRC_ROOT/$d"; then
    find "$SRC_ROOT/$d" -maxdepth 1 -name '*.o' -delete 2>/dev/null || true
  fi
done
# A stray vpi/libvpi.a in the source tree satisfies the libvpi.a make rule via
# VPATH but is not in the build directory; the linker only sees -L. (obj dir) and
# fails with: wasm-ld: unable to find library -lvpi
rm -f "$SRC_ROOT/vpi/libvpi.a" "$SRC_ROOT/vpi/libvpi.o" 2>/dev/null || true

echo "==> Configuring in $BUILD_DIR (fresh)"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
# Intentionally no --disable-wasm-dylink: keep MAIN_MODULE/SIDE_MODULE for browser dlopen.
emconfigure "$SRC_ROOT/configure" \
  CFLAGS='-Wall -Wextra -Wshadow -Wstrict-prototypes -Os -g0' \
  CXXFLAGS='-Wall -Wextra -Wshadow -Os -g0' \
  LDFLAGS='-O2'

{
  echo "=== wasm dylink lines in generated Makefile (expect WASM_LDFLAGS_MAIN non-empty) ==="
  grep -E 'WASM_DYLINK|WASM_LDFLAGS_MAIN|WASM_ICARUS|PACK_WASM' "$BUILD_DIR/Makefile" 2>/dev/null | head -20 || true
  echo "=== configure summary (config.log tail) ==="
  tail -30 "$BUILD_DIR/config.log" 2>/dev/null || true
} >>"$LOG"

# version.c is built with host gcc (BUILDCC); GNU gcc does not accept -Oz.
echo "==> Patching root Makefile: version.exe uses gcc without -Oz"
sed -i '268s@.*@\t$(BUILDCC) $(CPPFLAGS) -Wall -Wextra -Wshadow -Wstrict-prototypes -O2 -g0 -o version.exe -I. -I$(srcdir) $(srcdir)/version.c@' \
  "$BUILD_DIR/Makefile"

(
  cd "$BUILD_DIR" || exit 1
  for d in . ivlpp vhdlpp vvp vpi tgt-null tgt-stub tgt-vvp tgt-vhdl tgt-vlog95 tgt-pcb tgt-blif tgt-sizer driver; do
    mkdir -p "$d/dep" 2>/dev/null || true
  done
)

# -j1: vpi/ must finish libvpi.a before any -lvpi link (parallel jobs race here).
echo "==> Building (pack only to wasm-web-bundle_icarus_static at end)"
emmake make -j1 all \
  WASM_ICARUS_PACK=: 2>&1 | tee -a "$LOG"

export WASM_SOURCE_REVISION_EXTRAS="BUILD_TYPE=wasm-web-compact-dylink
EMCC_FLAGS=compile:-Os -g0 link:-O2 (no -flto: LLVM segfault; no link -Os: dylink)
CONFIGURE_FLAGS=emconfigure (wasm dylink enabled; not --disable-wasm-dylink)
NOTE=Drop-in class same as wasm-web-bundle_icarus_dynamic; smaller than -O2 -g in-tree."

echo "==> Packing $SRC_ROOT/wasm-web-bundle_icarus_static"
"$SRC_ROOT/scripts/pack-wasm-bundle.sh" wasm-web-bundle_icarus_static "$BUILD_DIR"

OUT_BIN=$SRC_ROOT/wasm-web-bundle_icarus_static/bin
echo "==> Symlinks for node users: bin/*.js -> launcher (optional)"
for x in ivl vvp iverilog ivlpp vhdlpp; do
  if test -f "$OUT_BIN/$x"; then
    ln -sf "$x" "$OUT_BIN/$x.js" 2>/dev/null || true
  fi
done

{
  echo ""
  echo "=== post: dylink export check ==="
} >>"$LOG"
if node "$SRC_ROOT/scripts/check-icarus-dylink-exports.cjs" \
  "$OUT_BIN/ivl.wasm" "$OUT_BIN/vvp.wasm" >>"$LOG" 2>&1; then
  :
else
  echo "check-icarus-dylink-exports failed (see BUILD_LOG.txt)" >&2
  exit 1
fi

{
  echo ""
  echo "=== post: node smoke (version) ==="
} >>"$LOG"
for x in ivl vvp; do
  node "$OUT_BIN/$x" -V >>"$LOG" 2>&1 || node "$OUT_BIN/$x.js" -V >>"$LOG" 2>&1
done

echo "Done. Compare: ./scripts/compare-wasm-bundle-sizes.sh"
echo "Log: $LOG"
exit 0
