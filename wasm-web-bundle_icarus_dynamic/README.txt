wasm-web-bundle_icarus_dynamic
================================
Emscripten **dynamic linking** 빌드(`emcc` + 기본 `--enable-wasm-dylink`) 산출물을
`scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic` 로 모은 트리입니다.

- `bin/ivl`, `bin/vvp` 등은 **`-sMAIN_MODULE=2`** 로 링크되어 브라우저에서 `dlopen`으로
  `lib/ivl/*.tgt`, `lib/ivl/*.vpi` **SIDE_MODULE** 을 로드할 수 있게 맞춘 버전입니다.
- 예전 `-shared`만 쓰던 산출물과 바이너리가 다릅니다. wasm-tools 쪽 번들은 이 폴더로 교체해야 합니다.

dylink 시 SIDE_MODULE(`system.vpi` 등)은 **GOT.func / GOT.mem** 과 **`env` 함수 import**로
메인 모듈 심볼을 찾습니다. 링크에 libc·ivl이 있어도 **wasm export 테이블에 이름이 없으면**
`undefined symbol` 이 납니다. `stderr`만이 아니라 `__cxa_atexit`, `vpi_*`, `pthread_*` 등
수백 개가 이어질 수 있어, 개별 `-Wl,--export=` 보다 **`-Wl,--export-all`** 이 현실적입니다.

이 저장소는 `ivl`/`vvp` MAIN_MODULE 링크에 다음이 포함됩니다.

- `EMCC_FORCE_STDLIBS=1`
- `-sMAIN_MODULE=2 -sALLOW_MEMORY_GROWTH -Wl,--export-all`

검사: `node scripts/check-icarus-dylink-exports.cjs` — `system.vpi`가 메인에서 기대하는 심볼만 검사합니다.
`system.vpi` **자체 export**(PIC용 GOT 등)는 제외하고, 나머지는 `ivl.wasm` **export** 또는
`ivl.wasm`이 이미 `env`로 받는 함수(import)면 통과(`exit` 등은 JS가 넣는 경우).

재생성: 저장소 루트에서 `emconfigure`/`emmake make` 하면 **루트 `make all` 끝에서**
`wasm-web-bundle_icarus_dynamic/` 가 자동으로 갱신됩니다(emcc일 때만).
수동으로만 할 때는 `scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic` 입니다.
