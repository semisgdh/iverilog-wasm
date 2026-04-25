wasm-web-bundle_icarus_static
===============================

GPL-2.0 / corresponding source — see `CORRESPONDING_SOURCE.md` and `SOURCE_REVISION.txt`.

## What this bundle is (current)

**Low-size WASM with Emscripten dylink still enabled** (`MAIN_MODULE=2`, side `.vpi` / `.tgt`,
`dlopen`). This is the **same execution class** as `wasm-web-bundle_icarus_dynamic/` (e.g. loads
`/lib/ivl/system.vpi`, `vvp.tgt`), **not** the old `--disable-wasm-dylink` profile that caused
`dynamic linking not enabled` in the browser.

- **Build:** `./scripts/build-icarus-wasm-static-oz.sh`  
  - Out-of-tree dir: `build-icarus-oz-dylink/` (default)  
  - Flags: compile `-Os -g0`, link `-O2` (no `-flto` — `-O2 -flto` can crash LLVM on e.g. `PExpr.cc`; not `-Oz` on compile; link not `-Os` or dylink breaks); **no** `--disable-wasm-dylink`  
- **Verification on success:** `scripts/check-icarus-dylink-exports.cjs` must report **OK** for
  `bin/ivl.wasm` and `bin/vvp.wasm` (see `BUILD_LOG.txt` after a build).

### dylink check: default vs `--strict` (important for CI)

Run **without** `--strict` (this is the meaningful gate for “will `system.vpi` load?”):

```bash
node scripts/check-icarus-dylink-exports.cjs path/to/bin/ivl.wasm path/to/bin/vvp.wasm
```

Do **not** use `--strict` as a pass/fail release check. In `--strict` mode, the script requires
**every** `system.vpi` import to appear in `ivl.wasm` *wasm exports*; on a normal Emscripten dylink
build, **dozens of names** (e.g. libc `exit`, C++ `std::` internals, flex buffers) are satisfied via
**`env` imports** or the side module’s own exports — so **`--strict` is expected to report ~70+
“missing”** even when the build is correct. The default mode encodes that model; see
`check-icarus-dylink-exports.cjs` header and `wasm-web-bundle_icarus_dynamic/README.txt`.

## Compatibility with JS runtimes (e.g. homepage_init)

| Goal | Expectation |
|------|-------------|
| Same `module:` / `target:` / FS paths as dynamic | **Yes** — dylink + side modules match the dynamic bundle model. |
| Drop-in vs `wasm-web-bundle_icarus_dynamic` | **Mostly** — same tree layout (`bin/`, `lib/ivl/`). Re-test your `runIcarusPipeline` / `fetchIcarusLib` / `sync-icarus-wasm` once. |
| Extensionless launcher + `.wasm` | Unchanged; optional `bin/ivl.js` → `ivl` symlinks are created by the build script for `node bin/ivl.js` style calls. |

**Conclusion field for integrators:** after this profile change, the bundle is intended to be a
**drop-in candidate** for the same browser pipeline that used `icarus_dynamic`, with **smaller wasm**
than a typical `-O2 -g` in-tree build. Any remaining mismatch is usually **path sync** or **Emscripten
Module** options in app code, not missing `dlopen`.

## Size vs dynamic (order of magnitude)

Run from repo root:

```bash
./scripts/compare-wasm-bundle-sizes.sh
```

Typical: **-Os -g0 + dylink** (link `-O2`) total `*.wasm` is **smaller** than **in-tree dynamic** built with `-O2 -g`,
but **larger** than the obsolete no-dylink “static” experiment (~2 MiB all-wasm). Exact numbers are
machine- and Emscripten-version-dependent; the compare script prints bytes and IEC units.

## Optional: post-pack `wasm-opt` (extra shrink)

After `pack-wasm-bundle.sh`, you can run Binaryen on all `*.wasm`, `lib/ivl/*.vpi`, and `*.tgt` in the tree:

```bash
./scripts/wasm-opt-icarus-bundle.sh --verify wasm-web-bundle_icarus_static
```

Uses the emsdk `wasm-opt` with bulk-memory / sign-ext / nontrapping-float-to-int (required for Emscripten output). Typical extra savings are on the order of **~1%** of **all** wasm-like files combined; `check-icarus-dylink-exports.cjs` should still report **OK** after a good run.

## Files

- `BUILD_LOG.txt` — created when you run the build script (configure tail, `make` log, dylink check, node smoke).
- `FILE_MANIFEST.txt` — expected layout.
