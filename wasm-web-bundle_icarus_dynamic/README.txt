wasm-web-bundle_icarus_dynamic
================================

GPL-2.0 / corresponding source (short)
----------------------------------------
WASM and JS wrappers here are built from **Icarus Verilog** (GPL-2.0) on the **semisgdh/iverilog-wasm**
`wasm-port` branch.

- **Upstream:** https://github.com/steveicarus/iverilog
- **This fork (WASM build):** https://github.com/semisgdh/iverilog-wasm (branch `wasm-port`)

For public notices, prefer the full commit SHA from **`SOURCE_REVISION.txt`** (or a **release tag** that
points to that commit), not the branch name alone. After packing, this folder also has:

- **`CORRESPONDING_SOURCE.md`** — full English corresponding-source note (same as `docs/CORRESPONDING_SOURCE.md`)
- **`SOURCE_REVISION.txt`** — Git commit and date used for this bundle

Product-specific compliance: consult counsel if needed.

---

Emscripten **dynamic linking** output (`emcc` with `--enable-wasm-dylink`), gathered with
`scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic`.

- `bin/ivl`, `bin/vvp`, etc. are linked with **`-sMAIN_MODULE=2`** so the browser can `dlopen`
  `lib/ivl/*.tgt` and `lib/ivl/*.vpi` **SIDE_MODULE** files.
- Binaries differ from older `-shared`-only builds; replace wasm-tools bundles with this tree when switching.

With dylink, SIDE_MODULEs (`system.vpi`, etc.) resolve main-module symbols via **GOT.func / GOT.mem**
and **`env` function imports**. If a name is missing from the wasm export table you get **`undefined symbol`**
(not only `stderr`; `__cxa_atexit`, `vpi_*`, `pthread_*`, etc.). Per-symbol `-Wl,--export=` is impractical;
**`-Wl,--export-all`** on the main module is the practical approach.

This repo links `ivl` / `vvp` MAIN_MODULE with:

- `EMCC_FORCE_STDLIBS=1`
- `-sMAIN_MODULE=2 -sALLOW_MEMORY_GROWTH -Wl,--export-all`

Check: `node scripts/check-icarus-dylink-exports.cjs` — default mode checks symbols `system.vpi` truly
needs from the main (excluding its own PIC/GOT exports). Missing names may be satisfied by **`ivl.wasm` wasm
exports** or **`env` imports** on `ivl.wasm` (`exit`, `__assert_fail`, `__cxa_throw`, etc., filled by
Emscripten JS).

**Note:** Matching every GOT/env name only to `ivl.wasm` exports reports ~**72** “missing”; most are
already exported from the same `system.vpi` or resolved inside side modules. A few (e.g. `exit`) are
**imported via `env`** and need not appear as wasm exports. For a raw export-table view:
`node scripts/check-icarus-dylink-exports.cjs --strict …` (expected to fail; summary prints at the end).

Regenerate: from repo root, `emconfigure` / `emmake make` — at end of **`make all`**, this directory
updates automatically when using `emcc`. To pack only: `scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic`.
