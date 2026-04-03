wasm-web-bundle_icarus_dynamic
================================
Emscripten **dynamic linking** 빌드(`emcc` + 기본 `--enable-wasm-dylink`) 산출물을
`scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic` 로 모은 트리입니다.

- `bin/ivl`, `bin/vvp` 등은 **`-sMAIN_MODULE=2`** 로 링크되어 브라우저에서 `dlopen`으로
  `lib/ivl/*.tgt`, `lib/ivl/*.vpi` **SIDE_MODULE** 을 로드할 수 있게 맞춘 버전입니다.
- 예전 `-shared`만 쓰던 산출물과 바이너리가 다릅니다. wasm-tools 쪽 번들은 이 폴더로 교체해야 합니다.

dylink 시 브라우저에서 `undefined symbol 'stderr'` 가 나오면, MAIN_MODULE(`ivl`/`vvp`)에
libc 전역이 안 실린 경우입니다. 이 저장소는 configure가 **`EMCC_FORCE_STDLIBS=1`** 을
MAIN_MODULE 링크 줄에 붙이도록 되어 있으니, 최신 소스로 다시 `emconfigure`/`emmake make` 후
pack 하면 됩니다. (수동으로는 `EMCC_FORCE_STDLIBS=1 emmake make` 도 동일 목적.)

재생성: 저장소 루트에서 `emconfigure`/`emmake make` 후 위 pack 스크립트를 실행합니다.
