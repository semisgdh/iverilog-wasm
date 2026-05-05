# Corresponding source (GPL-2.0)

The WebAssembly artifacts in this directory layout (for example `wasm-web-bundle_icarus_dynamic/`) are derived from **Icarus Verilog** and are licensed under the **GNU General Public License, version 2** (GPL-2.0). The full license text ships with the source tree as `COPYING` in the repository below.

This file is meant to help distributors and end users locate **corresponding source** in the GPL sense. It is **not legal advice**; for product-specific compliance (e.g. SaaS, WASM-only delivery, combination with proprietary code), consult qualified counsel.

**License text:** the complete GPL-2.0 license for Icarus Verilog is in the **`COPYING`** file at the root of the upstream repository and of this fork. Redistributing binaries (including WASM) does not remove the obligation to honor GPL-2.0 terms for those binaries and their corresponding source.

## Upstream project

| | |
|---|---|
| **Project** | Icarus Verilog |
| **Copyright** | Stephen Williams and contributors (see upstream credits) |
| **Upstream repository** | https://github.com/steveicarus/iverilog |
| **License** | GPL-2.0 (`COPYING` in that repository) |

## Fork used for Emscripten / WASM builds

| | |
|---|---|
| **Repository** | https://github.com/semisgdh/iverilog-wasm |
| **Branch** | `wasm-port` (WASM + dynamic linking tooling) |

Upstream and this fork are both GPL-2.0. Your **open-source notices** (e.g. “open source licenses” pages) should name **both** upstream Icarus and the **exact fork revision** you ship, so readers are not confused about which sources match the binaries you distribute.

## Exact revision for *this* bundle

When the bundle is produced, **`SOURCE_REVISION.txt`** (next to this file in the bundle directory) is written by `scripts/pack-wasm-bundle.sh`. It records:

- Full Git commit SHA of the checkout that was packed  
- Short SHA, commit date, and current branch name (when available)

**Pin your public documentation to that full SHA or to a release tag** that points at it. A branch name alone (`wasm-port`) can move; a commit or tag gives a stable “corresponding source” snapshot.

When the packed commit is exactly at an annotated or lightweight tag, **`SOURCE_REVISION.txt`** also includes a line `GIT_TAG_EXACT=...`. Cite that tag (and optionally a GitHub Release URL) in your product notices alongside the SHA.

### Release tags on this fork

Maintainers publish **annotated** tags named like **`wasm-web-bundle-1.0.0`**, **`wasm-web-bundle-1.0.1`**, … for snapshots intended for redistribution. To obtain the same sources as a tagged build:

```bash
git clone https://github.com/semisgdh/iverilog-wasm.git && cd iverilog-wasm && git checkout wasm-web-bundle-1.0.0
```

Example permalink (after the tag exists on GitHub):  
https://github.com/semisgdh/iverilog-wasm/releases/tag/wasm-web-bundle-1.0.0  

Creating a **GitHub Release** from the tag (with release notes) is optional but makes the download entry point obvious for recipients.

If `SOURCE_REVISION.txt` is missing, run `./scripts/pack-wasm-bundle.sh` from a Git checkout of this fork, or ask the distributor for the exact revision used to build the WASM you received.

## Rebuild this bundle (typical one-line flow)

Prerequisites: Emscripten (`emcc`/`em++`), `autoconf`, `flex`, `bison`, `gperf`, `make`, and a normal Unix toolchain.

```bash
git clone https://github.com/semisgdh/iverilog-wasm.git && cd iverilog-wasm && git checkout <SHA_FROM_SOURCE_REVISION.txt> && autoconf && emconfigure ./configure && emmake make all
```

With `CC` set to `emcc`, `make all` at the repository root refreshes `wasm-web-bundle_icarus_dynamic/` automatically at the end. Alternatively, after a successful Emscripten build:

```bash
./scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic
```

Optional export check (requires Node.js):

```bash
node scripts/check-icarus-dylink-exports.cjs wasm-web-bundle_icarus_dynamic/bin/ivl.wasm wasm-web-bundle_icarus_dynamic/bin/vvp.wasm
```

## Smaller bundle (out-of-tree, compile `-Os -g0`, link `-O2`, **dylink kept**)

For a **deploy tree** with the **same** wasm dylink model as `wasm-web-bundle_icarus_dynamic/`
(keep `dlopen` of `.vpi` / `.tgt`), build **out of tree** and **do not** pass `--disable-wasm-dylink`:

```bash
./scripts/build-icarus-wasm-static-oz.sh
```

This uses compile `-Os -g0` and link `-O2` (no `-flto`—`-O2 -flto` can crash LLVM on e.g. `PExpr.cc` on some toolchains, not only `-Oz -flto`). Link avoids `-Os`, which can strip dylink re-exports. It sets
`BUILD_TYPE=wasm-web-compact-dylink` in `SOURCE_REVISION.txt`.

**Old mistake:** using `--disable-wasm-dylink` for size broke browsers with
`dynamic linking not enabled` when loading `system.vpi` / `vvp.tgt`. The script above leaves dylink on.

## Copying this file

Maintainers: `CORRESPONDING_SOURCE.md` lives in-repo as `docs/CORRESPONDING_SOURCE.md` and is copied into each packed bundle by `pack-wasm-bundle.sh` so a **folder-only** distribution (e.g. `wasm-web-bundle_icarus_dynamic` without the rest of the repo) still carries source-attribution text alongside the binaries.
