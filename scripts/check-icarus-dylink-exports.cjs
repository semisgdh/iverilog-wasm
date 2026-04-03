#!/usr/bin/env node
/**
 * Verify MAIN_MODULE wasm exports what dylinked system.vpi needs:
 *   - stdin, stdout, stderr
 *   - GOT.{func,mem} imports from system.vpi: stdio + names starting with _Z (Itanium C++ ABI)
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

const needStdio = ['stdin', 'stdout', 'stderr'];

function findSystemVpi(ivlWasmPath) {
  if (path.basename(ivlWasmPath) !== 'ivl.wasm') return null;
  const dir = path.dirname(ivlWasmPath);
  const cands = [
    path.join(dir, '..', 'lib', 'ivl', 'system.vpi'),
    path.join(dir, '..', 'vpi', 'system.vpi'),
    path.join(repoRoot, 'vpi', 'system.vpi'),
  ];
  for (const c of cands) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

function gotSymbolsFromSystemVpi(vpiPath) {
  const mod = new WebAssembly.Module(fs.readFileSync(vpiPath));
  const imps = WebAssembly.Module.imports(mod);
  const out = new Set();
  for (const i of imps) {
    if (i.module !== 'GOT.func' && i.module !== 'GOT.mem') continue;
    const n = i.name;
    if (needStdio.includes(n) || n.startsWith('_Z')) out.add(n);
  }
  return out;
}

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
  const exportNames = new Set(WebAssembly.Module.exports(mod).map((e) => e.name));
  const rel = path.relative(repoRoot, wasmPath) || wasmPath;

  const missingStdio = needStdio.filter((n) => !exportNames.has(n));
  for (const n of missingStdio) {
    console.error(`${rel}: missing wasm export: ${n}`);
    exitCode = 1;
  }
  if (missingStdio.length) {
    console.error(
      '  Fix: -Wl,--export=stdin -Wl,--export=stdout -Wl,--export=stderr on MAIN_MODULE link',
    );
  }

  const vpiPath = findSystemVpi(wasmPath);
  let gotNeed = null;
  let missingGot = [];
  if (vpiPath) {
    try {
      gotNeed = gotSymbolsFromSystemVpi(vpiPath);
    } catch (e) {
      console.error(`${rel}: could not parse system.vpi (${vpiPath}): ${e.message}`);
      exitCode = 2;
      continue;
    }
    missingGot = [...gotNeed].filter((n) => !exportNames.has(n));
    for (const n of missingGot) {
      console.error(`${rel}: missing wasm export (required by system.vpi GOT): ${n}`);
      exitCode = 1;
    }
    if (missingGot.length) {
      console.error(`  system.vpi: ${path.relative(repoRoot, vpiPath) || vpiPath}`);
      console.error(
        '  Fix: add -Wl,--export=<name> for each on ivl MAIN_MODULE (see configure.ac WASM_LDFLAGS_MAIN).',
      );
    }
  }

  if (missingStdio.length === 0 && missingGot.length === 0) {
    if (gotNeed && gotNeed.size)
      console.log(
        `${rel}: OK (stdio + ${gotNeed.size} GOT symbol(s) from system.vpi, incl. libc++ / std::length_error)`,
      );
    else console.log(`${rel}: OK (${needStdio.join(', ')} exported)`);
  }
}

process.exit(exitCode);
