wasm-web-bundle_icarus_dynamic
================================
Emscripten **dynamic linking** 빌드(`emcc` + 기본 `--enable-wasm-dylink`) 산출물을
`scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic` 로 모은 트리입니다.

- `bin/ivl`, `bin/vvp` 등은 **`-sMAIN_MODULE=2`** 로 링크되어 브라우저에서 `dlopen`으로
  `lib/ivl/*.tgt`, `lib/ivl/*.vpi` **SIDE_MODULE** 을 로드할 수 있게 맞춘 버전입니다.
- 예전 `-shared`만 쓰던 산출물과 바이너리가 다릅니다. wasm-tools 쪽 번들은 이 폴더로 교체해야 합니다.

재생성: 저장소 루트에서 `emconfigure`/`emmake make` 후 위 pack 스크립트를 실행합니다.
