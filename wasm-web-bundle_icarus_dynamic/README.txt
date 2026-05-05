wasm-web-bundle_icarus_dynamic
================================
This tree collects the Emscripten **dynamic linking** build output (`emcc` with
`--enable-wasm-dylink`) via `scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic`.

- `bin/ivl`, `bin/vvp`, etc. are linked with **`-sMAIN_MODULE=2`** so the browser can
  `dlopen` `lib/ivl/*.tgt` and `lib/ivl/*.vpi` **SIDE_MODULE** plugins.
- The binaries differ from older builds that used `-shared` only. wasm-tools bundles
  should be replaced with this layout.

With dylink, SIDE_MODULEs (e.g. `system.vpi`) resolve main-module symbols via
**GOT.func / GOT.mem** and **`env` function imports**. Even if libc and ivl are linked in,
you get **`undefined symbol`** if the name is missing from the **Wasm export table**—not
only for `stderr`, but for hundreds of symbols such as `__cxa_atexit`, `vpi_*`, `pthread_*`, etc.
Per-symbol `-Wl,--export=` is impractical; **`-Wl,--export-all`** is the realistic choice.

This repository’s `ivl` / `vvp` MAIN_MODULE links include:

- `EMCC_FORCE_STDLIBS=1`
- `-sMAIN_MODULE=2 -sALLOW_MEMORY_GROWTH -Wl,--export-all`

Check: `node scripts/check-icarus-dylink-exports.cjs` — **default mode** (recommended) only
looks at symbols `system.vpi` truly needs from the main module. It excludes `system.vpi`’s
**own exports** (PIC GOT slots); the rest must be satisfied by **`ivl.wasm` Wasm exports** or
by **`env` function imports** on `ivl.wasm` (`exit`, `__assert_fail`, `__cxa_throw`, etc.—filled
in by Emscripten JS).

**Avoid a common misread:** If you require every GOT/env name to appear only in `ivl.wasm`
exports, roughly **72** will show as “missing.” Most of those (`sys_*_register`, `readmem*`,
`sdf*`, …) are symbols **already exported by the same `system.vpi`** and resolve inside the
side module at runtime. A handful like `exit` are **imported by ivl as `env`** and are fine
without a Wasm export. For a raw export-table-only view: `node scripts/check-icarus-dylink-exports.cjs --strict …`
(failure is expected; a short summary of the above is printed at the end).

Regenerate: From the repo root, `emconfigure` / `emmake make` — at the end of **`make all`**,
`wasm-web-bundle_icarus_dynamic/` is refreshed automatically (only when using emcc). For a
manual pack only: `scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic`.
