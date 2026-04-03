#!/usr/bin/env node
/**
 * Verify MAIN_MODULE wasm exports stdin/stdout/stderr (required for dylink side modules).
 *
 * Usage:
 *   node scripts/check-icarus-dylink-exports.cjs [ivl.wasm [vvp.wasm ...]]
 * Defaults (from repo root): ./ivl.wasm ./vvp/vvp.wasm
 */
'use strict';

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const defaultPaths = [path.join(repoRoot, 'ivl.wasm'), path.join(repoRoot, 'vvp', 'vvp.wasm')];
const wasmPaths =
  process.argv.length > 2 ? process.argv.slice(2).map((p) => path.resolve(p)) : defaultPaths;

const need = ['stdin', 'stdout', 'stderr'];
let exitCode = 0;

for (const wasmPath of wasmPaths) {
  if (!fs.existsSync(wasmPath)) {
    console.error(`skip (missing): ${wasmPath}`);
    continue;
  }
  let mod;
  try {
    mod = new WebAssembly.Module(fs.readFileSync(wasmPath));
  } catch (e) {
    console.error(`${wasmPath}: parse error: ${e.message}`);
    exitCode = 2;
    continue;
  }
  const names = new Set(WebAssembly.Module.exports(mod).map((e) => e.name));
  const missing = need.filter((n) => !names.has(n));
  const rel = path.relative(repoRoot, wasmPath) || wasmPath;
  if (missing.length) {
    console.error(`${rel}: missing wasm exports: ${missing.join(', ')}`);
    console.error(
      '  Fix: link ivl/vvp MAIN_MODULE with -Wl,--export=stdin -Wl,--export=stdout -Wl,--export=stderr',
    );
    exitCode = 1;
  } else {
    console.log(`${rel}: OK (${need.join(', ')} exported)`);
  }
}

process.exit(exitCode);
