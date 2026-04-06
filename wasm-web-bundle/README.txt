wasm-web-bundle
===============
Layout of Emscripten build outputs as an install-tree-shaped folder.

  bin/              iverilog, ivl, ivlpp, vvp, vhdlpp (each with a matching .wasm)
  lib/ivl/          target *.tgt, *.conf, system *.vpi
  lib/ivl/include/  constants.vams, disciplines.vams

Example using the bundle root like a prefix locally:
  bin/iverilog -Bbin -o out.vvp ...   (or put bin on PATH and use -B<absolute-path>/bin)

Note: host `iverilog` spawns child tools via fork/exec and system(). That may not work unchanged
in browser WASM; on the web you may need JS glue for Module/FS or a different process model.

Regenerate: from repo root after `emmake make`:
  ./scripts/pack-wasm-bundle.sh
  ./scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic
(First argument is the destination directory; for browser dlopen see `wasm-web-bundle_icarus_dynamic/README.txt`.)

If you configured with `emcc`, root `make all` refreshes `wasm-web-bundle_icarus_dynamic/` at the end,
so the dylink bundle can stay current without a separate pack step.

Check: `node scripts/check-icarus-dylink-exports.cjs ivl.wasm vvp/vvp.wasm` — verifies the dylink
MAIN_MODULE exports the GOT/env symbols `system.vpi` needs (usually requires `-Wl,--export-all`).
