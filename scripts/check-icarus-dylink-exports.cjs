#!/usr/bin/env node
/**
 * Verify MAIN_MODULE ivl.wasm satisfies dylinked system.vpi:
 *   - stdin, stdout, stderr exported from ivl.wasm
 *   - Every symbol system.vpi needs from the host, either:
 *       - exported from ivl.wasm, or
 *       - imported by ivl.wasm from env (JS provides at instantiation; dyloader wires side modules), or
 *       - exported by system.vpi itself (GOT for PIC in the side module — not ivl's job)
 *
 * system.vpi imports: GOT.func / GOT.mem (WebAssembly kind "global") + env functions.
 * env globals __memory_base / __table_base are not listed as imports with kind "function" — ignored.
 *
 * vvp.wasm: only stdin, stdout, stderr.
 *
 * Usage:
 *   node scripts/check-icarus-dylink-exports.cjs [ivl.wasm [vvp.wasm ...]]
 */
'use strict';

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const defaultPaths = [path.join(repoRoot, 'ivl.wasm'), path.join(repoRoot, 'vvp', 'vvp.wasm')];
const wasmPaths =
  process.argv.length > 2 ? process.argv.slice(2).map((p) => path.resolve(p)) : defaultPaths;

const needStdio = ['stdin', 'stdout', 'stderr'];
const PREVIEW_LIMIT = 40;

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

function hostSymbolsRequiredBySystemVpi(vpiPath) {
  const mod = new WebAssembly.Module(fs.readFileSync(vpiPath));
  const imps = WebAssembly.Module.imports(mod);
  const vpiExports = new Set(
    WebAssembly.Module.exports(mod).map((e) => e.name),
  );
  const need = new Set();
  for (const i of imps) {
    if (i.module === 'GOT.func' || i.module === 'GOT.mem') {
      need.add(i.name);
    } else if (i.module === 'env' && i.kind === 'function') {
      need.add(i.name);
    }
  }
  return [...need].filter((n) => !vpiExports.has(n));
}

function envFunctionImports(wasmPath) {
  const mod = new WebAssembly.Module(fs.readFileSync(wasmPath));
  const imps = WebAssembly.Module.imports(mod);
  return new Set(
    imps.filter((i) => i.module === 'env' && i.kind === 'function').map((i) => i.name),
  );
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
      '  Fix: -Wl,--export=stdin -Wl,--export=stdout -Wl,--export=stderr (or -Wl,--export-all) on MAIN_MODULE link',
    );
  }

  const vpiPath = findSystemVpi(wasmPath);
  let requiredFromHost = null;
  let missingHost = [];
  let ivlEnvImports = null;

  if (vpiPath) {
    try {
      requiredFromHost = hostSymbolsRequiredBySystemVpi(vpiPath);
      ivlEnvImports = envFunctionImports(wasmPath);
    } catch (e) {
      console.error(`${rel}: could not parse (${vpiPath}): ${e.message}`);
      exitCode = 2;
      continue;
    }

    missingHost = requiredFromHost
      .filter((n) => !exportNames.has(n) && !ivlEnvImports.has(n))
      .sort();

    for (const n of missingHost) {
      console.error(`${rel}: not exported from ivl.wasm and not an ivl env import: ${n}`);
      exitCode = 1;
    }
    if (missingHost.length) {
      const preview = missingHost.slice(0, PREVIEW_LIMIT).join(', ');
      const more =
        missingHost.length > PREVIEW_LIMIT ? ` … (+${missingHost.length - PREVIEW_LIMIT} more)` : '';
      console.error(`  (${missingHost.length} unresolved; first: ${preview}${more})`);
      console.error(`  system.vpi: ${path.relative(repoRoot, vpiPath) || vpiPath}`);
      console.error(
        '  Fix: ivl MAIN_MODULE with -Wl,--export-all; if still failing, add -Wl,--export=<sym> or extend JS env.',
      );
    }
  }

  if (missingStdio.length === 0 && missingHost.length === 0) {
    if (requiredFromHost && requiredFromHost.length && vpiPath) {
      const viaExport = requiredFromHost.filter((n) => exportNames.has(n)).length;
      const viaEnv = requiredFromHost.filter((n) => ivlEnvImports.has(n)).length;
      console.log(
        `${rel}: OK (system.vpi → host ${requiredFromHost.length} symbols: ${viaExport} ivl wasm export, ${viaEnv} ivl env import)`,
      );
    } else {
      console.log(`${rel}: OK (${needStdio.join(', ')} exported)`);
    }
  }
}

process.exit(exitCode);
