wasm-web-bundle
===============
Emscripten 산출물을 "설치 트리" 모양으로 모은 폴더입니다.

  bin/          iverilog, ivl, ivlpp, vvp, vhdlpp (각각 .wasm 짝)
  lib/ivl/      타깃 *.tgt, *.conf, 시스템 *.vpi
  lib/ivl/include/  constants.vams, disciplines.vams

로컬에서 번들 루트를 prefix처럼 쓰려면 예:
  bin/iverilog -Bbin -o out.vvp ...   (또는 PATH에 bin 넣고 -B<절대경로>/bin)

주의: 호스트 iverilog는 fork/exec·system()으로 하위 도구를 띄웁니다.
브라우저 WASM에서는 그대로 동작하지 않을 수 있어, 웹에서는 별도 JS에서
Module/FS를 맞추거나 프로세스 모델을 바꿔야 할 수 있습니다.

재생성: 저장소 루트에서 emmake make 후
  ./scripts/pack-wasm-bundle.sh
  ./scripts/pack-wasm-bundle.sh wasm-web-bundle_icarus_dynamic
 (첫 인자로 대상 디렉터리 지정 가능; 브라우저 dlopen용은 icarus_dynamic 쪽 README 참고.)
emcc로 configure 했을 때는 루트 `make all` 마지막에 `wasm-web-bundle_icarus_dynamic/` 가
자동 갱신되므로, dylink 번들은 별도 pack 없이도 최신을 유지할 수 있습니다.

검사: `node scripts/check-icarus-dylink-exports.cjs ivl.wasm vvp/vvp.wasm` — dylink용 MAIN_MODULE에
stdin/stdout/stderr export가 있는지 확인합니다.
