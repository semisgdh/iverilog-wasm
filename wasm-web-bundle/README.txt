wasm-web-bundle
===============
Folder layout that collects Emscripten output in an “install tree” shape.

  bin/              iverilog, ivl, ivlpp, vvp, vhdlpp (each with a matching .wasm)
  lib/ivl/          targets *.tgt, *.conf, system *.vpi
  lib/ivl/include/  constants.vams, disciplines.vams

Example of using the bundle root locally like a prefix:
  bin/iverilog -Bbin -o out.vvp ...   (or put bin on PATH and use -B<absolute>/bin)

Note: The host `iverilog` driver spawns child tools via fork/exec and system().
That model does not map directly to browser Wasm; on the web you typically wire up
Module/FS in JS or adjust the process model.

Regenerate: After `emmake make` at the repo root:
  ./scripts/pack-wasm-bundle.sh
  ./scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic
(You can pass the target directory as the first argument; for the browser `dlopen`
bundle see `wasm-web-bundle_icarus_dynamic/README.txt`.)

When configured with emcc, root **`make all`** refreshes `wasm-web-bundle_icarus_dynamic/`
at the end, so the dylink bundle can stay up to date without a separate pack step.

Check: `node scripts/check-icarus-dylink-exports.cjs ivl.wasm vvp/vvp.wasm` — verifies that
dylink MAIN_MODULEs export the GOT/env symbols `system.vpi` needs (usually requires `-Wl,--export-all`).
