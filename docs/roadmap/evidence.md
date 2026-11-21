# Evidence log

This file started with no technical results. Entries must record observed facts, not goals.

## Entry template

```text
### YYYY-MM-DD — phase/milestone
- Repository revision:
- Host and OS:
- Reference snl/snovac (version and path):
- Command(s):
- Observed result:
- Artifacts/hash:
- Limitations and unverified items:
```

## 2026-11-21 — Snova seed and restricted fixed point

- Reference repository revision: `snovac` `2b5048aaf221527e22ea844f858b5d0f33f149c9` (local checkout; read-only).
- Host and OS: Apple Silicon, macOS; observed triple `aarch64-apple-darwin`.
- `snl`: `snl v0.3.0` (`/Users/yurimoinhos/.snova/bin/snl`).
- Observed commands: `make bootstrap-fixed-point` (chained join, check, build, self-host and compare targets).
- Observed result: check and the (then called "native") build passed; the seed compiled its own source to SnBC; the second image compared byte for byte equal to the first.
- SHA-256 of the two compared images: `2bff50e2757bd6fbd252f375832c445aa1b20a48aa9876bbe126f0da9e4482d1`.
- Limitations: a result for the subset implemented in the seed, using the `snl` runtime; it does not prove a full CLI, compilation of the `snovac` source, standalone execution without the C runtime, an independent reproducible build, DDC or general equivalence. The provenance of the imported source is in `bootstrap/README.md`.

## 2026-11-21 — seed smoke test and diagnostics

- Revision and host: same as the previous entry; `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-smoke`, `make bootstrap-diagnostics`, `make bootstrap-fixed-point`.
- Observed result: a fixture program compiled by the seed and run by the SnBC runtime printed `snova bootstrap ok`; lexically and syntactically invalid inputs failed with the expected phase and line; compiling its own source with the generated SnBC produced an image equal to the previous one.
- SHA-256 of both images of the restricted fixed point: `632aab95921a0ac749b8dca5ab575498f8a1ab004ad6636af148740f97ae1ef7`.
- Limitations: lowering diagnostics are still generic and have no span; fixtures are not a differential against `snovac`; runtime, argument CLI and standalone backend remain pending.

## 2026-11-21 — importable modules and camelCase names

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Organization: compiler modules in `bootstrap/src/`, functions and types in `camelCase`, files under 400 lines. `api.snl` imports `snova.compiler`; `apiConsumer.snl` imports `snova.compiler.api`.
- Commands: `snl check --project bootstrap/src`, `make bootstrap-smoke`, `make bootstrap-diagnostics`, `make bootstrap-fixed-point`.
- Observed result: cross-package imports and the multi-file project passed the check; smoke test and diagnostics passed; the Snova joiner generated the seed unit, which compiled the sources and reached byte-for-byte equality.
- SHA-256 of the stage 1 and 2 SnBC images: `6dab7126700e6416ade1ba2df110ea8486dc6cae989954d484330a0919c42740`.
- Limitations: the seed does not load modules/imports on its own yet; the temporary joiner strips headers to self-compile. The execution runtime is still the one from `snl`; broad compatibility and a standalone backend were not demonstrated.

## 2026-11-21 — path-based I/O and internal bootstrap assembly

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-fixed-point`, `make bootstrap-smoke`, `make bootstrap-diagnostics`.
- Observed result: the multi-file project binary accepted input/output paths as arguments; without arguments it compiled its own sources through `sourceJoin.snl` and used `SNL_OUTPUT`. The generated SnBC repeated the compilation without the external joiner, and the two images matched byte for byte. Smoke test and diagnostics passed with the new CLI.
- SHA-256 of the two SnBC images: `4d00222c46e427a3308bf1f7ede3935d8a6744222f7d074a2f7ac115b2482716`.
- Limitations: `runtime.snl` wraps the argument, environment and byte calls, but those primitives and SnBC execution still come from the reference runtime. The internal assembly lists the compiler's own modules; general imports, full semantics, a Snova native backend and full compatibility with `snovac` remain pending.

## 2026-11-21 — structural SnBC reader in Snova

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-image-check`, `make bootstrap-fixed-point`.
- Observed result: `imageReader.snl` accepted the image produced by the compiler, rejected a truncated image and was compiled as part of the compiler itself in the next generation. The stage 1 and 2 images matched byte for byte.
- SHA-256 of both images: `8ecf10657461d96e7033ed391ba1fdfd60400579e503e36ff7d5dd5cec4952cd`.
- Limitations: validation covers structure, sizes and the main indexes; it did not yet validate instructions/opcodes, did not execute SnBC in Snova and did not replace the reference runtime or backend.

## 2026-11-21 — SnBC instruction validation in Snova

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-fixed-point`, `make bootstrap-image-check`, `make bootstrap-smoke`; images derived from `stage1.snbc` with an invalid opcode and an out-of-image jump were rejected by the Snova compiler.
- Observed result: `imageCode.snl` checked instruction bounds, the last opcode, string/local/function indexes, arity, runtime calls, jumps and not-yet-implemented opcodes; the stage 1 and 2 images matched byte for byte.
- SHA-256 of both images: `d85c9e395f93e2b16d8156dc47589f619b8d6693f6d935b79ddbc00b8100d3ee`.
- Limitations: this validator does not execute bytecode, does not prove parity for every corpus, and still uses the previous runtime to build/run the stage images.

## 2026-11-21 — numeric SnBC executor in Snova

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-vm-numeric bootstrap-fixed-point bootstrap-image-check bootstrap-smoke` and `git diff --check`.
- Observed result: `vmStack.snl` and `vmNumeric.snl` executed two images generated by the seed. Both returned `48`, equal to the exit status of `snl run-snbc` for the same images. The cases cover locals, arithmetic, comparison, conditional branch and loop. The restricted fixed point stayed byte-for-byte equal; SHA-256 of both images: `ce8b1d0daf76aad72e1ffb43622d7963a6ad219e2a46e69eec0c3e0af645e724`.
- Limitations: the executor accepted only one function and numeric/boolean values; it did not execute strings, calls, objects, arrays, I/O or the compiler's own image. Native generation and I/O primitives still depended on the previous runtime. This result is not a full replacement of `snovac`.

## 2026-11-21 — probes of the SnBC runtime v0.3.0 and of `snl build`

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`. Hand-assembled SnBC images (probe tool outside the repository) and programs compiled by the seed.
- Observed: `snl run-snbc` refuses an image with SET_INDEX (41) ("cannot read SnBC image"); SET_FIELD (38) expects the target on top and the value below, returning the value; `"ab" + "c" == "abc"` gives `false` and constants with the same content give `true` (string equality by identity, also in the `snl build` executable); `int + string` produces a spurious number; `bool == int` gives `false`; PRINT of unit prints an empty line; runtime calls 2/3/4 are `fileExists`, `readText` and `writeText`; the program receives no arguments (`argumentCount` = 0); depth overflow prints `error: call depth exceeded` with status 70.
- Observed: `snl build` generates SnBC and bundles the C VM ("bundled binary dependencies"; profile dominated by `run_function`); its lowering refuses `a[i].field` ("cannot lower field to SnBC"). The executables that earlier entries called a "native build" are therefore SnBC + C VM, not machine code of the program.
- Observed: `as -arch arm64` + `ld -lSystem` assemble and link an assembly `main` that returns 48; `ld` applies an ad-hoc signature (`adhoc,linker-signed`).
- Limitations: point probes; they do not cover every opcode or the full reference semantics.

## 2026-11-21 — the Snova SnBC executor runs the compiler image

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`; compiler executable produced by `snl build` (SnBC + bundled C VM).
- Commands: `make bootstrap-vm bootstrap-diagnostics bootstrap-fixed-point bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`, `git diff --check`.
- Observed result: the stdout and exit-status differential between the Snova executor (`<image> run`) and `snl run-snbc` passed for `numericVm` (48), `numericFlow` (48), `hello` (0), `vmCalls` (16, recursion) and `vmComposite` (14, structs/arrays/strings). `vmEquality` and `vmHostText` gave the fixed expected output (value equality; arguments passed through), diverging on purpose from `run-snbc`. `vmStackOverflow` failed with `runtime error: Stack overflow` and status 70. `invalidRuntimeArity` was rejected by the seed.
- Observed result: in `bootstrap-vm-self`, the Snova executor ran `stage1.snbc`; the guest compiler read its own sources, wrote `vm-stage.snbc` through `SNL_OUTPUT` and exited with 0. `stage1.snbc`, `stage2.snbc` (through `run-snbc`) and `vm-stage.snbc` matched byte for byte. SHA-256: `772cd2e01c2a2e7bc97ebc312d4c13679fb7e22b055d056817d6ac45d9ce563c`. Time: 3 min 08 s (185.6 s of CPU), against about 1 s for the compiler in the `snl build` executable.
- Limitations: the Snova executor runs on the C VM embedded by `snl build`, so execution still depends on the previous runtime and is not native (ADR-0005). Opcodes the compiler does not use (double, globals, variants, defer/spawn) are not executed. Errors go to stdout. Host strings use a scratch file in `/tmp` when compared (provisional boundary, ADR-0004). This is not DDC, clean-build reproducibility or a full replacement of `snovac`.

## 2026-11-21 — warning SNW0001 and a repeated executor gate

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-diagnostics bootstrap-vm bootstrap-fixed-point bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`, `git diff --check`.
- Observed result: `warnMismatch.snl` compiled with status 0 and two `warning[SNW0001]` diagnostics, at lines 10 (`"seven" == 7`) and 13 (struct `!=` int); `warnCompare.snl` compiled without diagnostics and returned 7 on the Snova executor. Compiling the compiler's own sources emitted no warnings. All quick gates passed.
- Observed result: the Snova executor ran the compiler image again with the current sources; `stage1.snbc`, `stage2.snbc` and `vm-stage.snbc` matched byte for byte. SHA-256: `e5aa78db2ad50a0898e2eaaea287b6ac6a66a39063a6f3fbc8c259ab4ddef2dc`. Time: 3 min 09 s (187.5 s of CPU). This hash replaced the previous entry's hash as the current state.
- Observed in `snl run-snbc` v0.3.0: in `warnCompare`, `true == (1 < 2)` gives false (status 3), while the Snova executor gives true (status 7). So the gate checks that fixture only through the Snova executor.
- Limitations: the warning only covers known static types (literals, typed locals, parameters, fields); calls and indexing have an unknown type and produce no warning. The span is only the line. Address comparison (`&T`) does not exist in the subset yet.

## 2026-11-21 — native backend N1 (ADR-0005)

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`; `as`/`ld` from the Command Line Tools (`-platform_version macos` = SDK version, `-lSystem`).
- Commands: `make bootstrap-native bootstrap-fixed-point bootstrap-vm bootstrap-diagnostics bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`, `git diff --check`.
- Observed result: the Snova compiler emitted aarch64 assembly for `numericVm`, `numericFlow` and `nativeCalls`; the assembled and linked arm64 Mach-O executables returned 48, 48 and 126, equal to the Snova executor and `snl run-snbc`. `hello.snl` was refused with `unsupported opcode for native backend: 3`. Two emissions of the same source gave identical `.s` files (SHA-256 of `nativeCalls.s`: `62345b3011b88abbfc36cb0ac6524a5cd76a00b2c05876f6569f63518f67fe4c`).
- Observed result: with the native modules in the sources, the fixed point and the executor gate kept passing; `stage1.snbc`, `stage2.snbc` and `vm-stage.snbc` matched. SHA-256: `47469d977b858b6b463acec9bce71475a3d87a7d23115e547fe5a2c939959951`.
- Limitations: N1 covered only the numeric subset (no strings, arrays, structs, printing or I/O); the compiler itself still runs in the `snl build` executable (SnBC + C VM); assembling and linking use the system `as`/`ld`; the generated code has no register allocation. There is no native fixed point and no native compiler (N3).

## 2026-11-21 — native runtime N2 with ownership (ADR-0006)

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`; `as`/`ld` from the Command Line Tools.
- Commands: `make bootstrap-native`, `make bootstrap-fixed-point bootstrap-vm bootstrap-diagnostics bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`; `/usr/bin/time -l` on `nativeMemory.native` with 1, 8 and 32 arguments; `nm -u` on the native executables.
- Observed result: in `native` mode the compiler appended `bootstrap/runtime/*.snl` to the program and emitted assembly for both. Against the Snova executor (stdout and exit status): `hello` (0), `vmCalls` (16), `vmComposite` (14), `vmEquality` (0), `vmStackOverflow` (70, `runtime error: Stack overflow`), `nativeHostIo` (105: byte and text files, `fileExists`, arguments `alpha beta`, smallest integer, negative division, struct/array equality, `null`) and `nativeMemory` (160) matched. `vmHostText` printed `true true true`, exited with 1 and wrote `probe` to its file. The numeric fixtures still matched the Snova executor and `snl run-snbc`. `nativeUnsupported` (enum variant) was refused with `unsupported opcode for native backend: 42`.
- Observed result (memory): with `SNOVA_MEMORY_REPORT=1`, every fixture that ends normally reported `live blocks 0, live bytes 0` at exit. `nativeMemory`, which allocates strings, arrays and objects every iteration and overwrites the previous ones, reported a peak of 1088 live bytes and a maximum resident set of 1 425 408 bytes for 20 000, 160 000 and 640 000 iterations (0.08 s, 0.66 s and 2.63 s). `nativeCycle` was rejected at the store that would close a cycle: `runtime error: strong reference cycle rejected for opcode 50`, status 70.
- Observed result (boundary): `nm -u` lists only `_close`, `_exit`, `_mmap`, `_munmap`, `_open`, `_read` and `_write`; `otool -L` lists only `libSystem.B.dylib`. The assembly of `vmHostText` does not mention `/tmp`. Two emissions of `nativeMemory.s` were identical (SHA-256 `eedc162d8e1fddc5135ac12f294877ce5c601b98f9fc04603ef57127d5b0ce11`).
- Observed result (self-compilation): with the N2 modules in the sources, `stage1.snbc`, `stage2.snbc` and `vm-stage.snbc` matched byte for byte. SHA-256: `532917fb7347cbd90374d79b801b921eebae3e7cd4eeca1baee2d395683ce215`. `bootstrap-vm-self` took 4 min 54 s (290.9 s of CPU).
- Limitations: the compiler itself is still built by `snl build` and is not compiled natively (N3). Ownership is analyzed in the backend over SnBC stack slots; the frontend does not yet reject use-after-move or aliasing errors. Programs that end with a runtime error exit without the memory report. Byte copies and the release of locals go through runtime calls (slow paths). Cyclic data is rejected instead of supported (no weak references). Assembling and linking still use the system `as`/`ld`.

## 2026-11-21 — native compiler fixed point N3

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`, macOS SDK 26.5; Command Line Tools `as`/`ld`.
- Command: `make bootstrap-native-self`.
- Observed result: the transitional `snl` seed emitted assembly for the ordered compiler modules plus the Snova native runtime. The linked native compiler compiled the same source, and the next linked native compiler repeated the build. Both assembly comparisons passed byte-for-byte.
- SHA-256 of the fixed-point compiler assembly: `796443bb0543c3f0b19b12f2b82bb80b9fd7347b90833929bcb43575a0c6cf82` (same hash for all three emissions in the direct run).
- Scope: native self-compilation and an assembly fixed point are demonstrated for this source order and host. Mach-O UUID/signature normalization, clean-environment reproducibility, independent DDC, general import resolution, and replacement of `snovac` are not demonstrated. The bootstrap still uses `snl` for its first compiler and `as`/`ld` to link every native stage.

## 2026-11-21 — stable frontend and lowering diagnostics

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-diagnostics bootstrap-fixed-point`, `python3 scripts/validate-planning-docs.py`, `git diff --check`.
- Observed result: lexical failures report `SNV1001` with a byte span, parser failures report `SNV2001` with the failing token span (including zero-width EOF spans), and lowering failures report `SNV3001` with line and function index. Positive warning fixtures remained unchanged. Diagnostic fixtures assert the complete output strings.
- Limitations: lowering span is not yet exact and the function index is not a stable symbol identity; semantic analysis still lacks structured diagnostics. Byte offsets are within the single input buffer, not mapped through source files because general import loading is not implemented.

## 2026-11-21 — local binding type annotations

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-diagnostics bootstrap-fixed-point bootstrap-native-self`, `python3 scripts/validate-planning-docs.py`, `git diff --check`.
- Observed result: the parser retains declared primitive or known struct types on `let`/`var` bindings. When both annotation and initializer types are known, a mismatch fails with `SNV4001` and the binding identifier span. The positive `typedLet` fixture returns 42; `invalidTypedLet` is rejected at byte span 54..55. Existing warning, SnBC fixed-point and native compiler fixed-point gates pass.
- Limitations: unknown expression types are not inferred or rejected; array annotations still map to the unknown type; assignment compatibility and function return types remain outside this slice.

## 2026-11-21 — local assignment type compatibility

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-diagnostics bootstrap-fixed-point bootstrap-native-self`, `python3 scripts/validate-planning-docs.py`, `git diff --check`.
- Observed result: assignment to a local with known type now rejects a known incompatible right-hand type using `SNV4002` and reports the binding identifier's byte span. Assignments where either side has unknown type retain the current subset behavior. Existing valid typed binding and earlier diagnostics remain gated.
- Limitations: assignment checks cover local variables only; fields, arrays, parameters, function returns and full subtype/nullable compatibility are not implemented.

## 2026-11-21 — field assignment type compatibility

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-diagnostics bootstrap-vm bootstrap-fixed-point bootstrap-native-self`, `python3 scripts/validate-planning-docs.py`, `git diff --check`.
- Observed result: assigning a known incompatible value to a known struct field is rejected with `SNV4003` and the field-name byte span. The positive field assignment returns 42; the negative fixture reports span 129..130. Local annotation and assignment diagnostics remain covered.
- Limitations: this check is limited to direct struct fields with known types; arrays, inherited fields, unknown expressions and other type relations remain unsupported.

## 2026-11-21 — array pop in SnBC and native backends

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-diagnostics bootstrap-native`, `make bootstrap-vm-self bootstrap-native-self`, `python3 scripts/validate-planning-docs.py`, `git diff --check`.
- Observed result: `ARRAY_POP` removes and returns the final element in both the Snova SnBC executor and the native backend. Integer and string fixtures pass; both backends report `runtime error: pop from empty array` with status 70. Native ownership reporting confirms zero live blocks at exit for successful pop fixtures.
- Limitations: the native backend supports the existing array layout and ownership model; this change does not add static array element typing or bounds/index assignment.

## 2026-11-21 — instance API for the search library (ADR-0007, SPEC-0001 slice 1)

- Repository revision: branch `mike/library-instance-api` on top of `2fba2df`.
- Host and OS: Linux 6.12, `x86_64-unknown-linux-gnu`; `snl v0.3.0` from the official Linux release (archive SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`).
- Probes (scratch files outside the repository): a fieldless class created with `Finder()`, with instance methods, an unqualified sibling call and the object passed as a typed parameter, passed `snl check` and `snl build`; the executable, `snl run-snbc` on the Snova compiler's image and the Snova executor all printed `2 false 1` and exited with 17. The current `librarySearch` fixture joined with the static `BinarySearch`/`LinearSearch` passed `snl check` but `snl build` rejected it with `invalid SnBC unit for native compilation`.
- Probes for later slices (scratch files outside the repository, same host and `snl`): a method of class `Holder` that runs `let alias = counter` (a field) and then `alias.bump(5)` passed `snl check`, but `snl build` failed with `error[SNOVA0400]: cannot lower call to SnBC` at `return alias.bump(5)`, then `error: failed to emit bytecode for 'aliasCall.snl'`; the seed compiled it and the Snova executor printed `6`. A method of class `Pool` that runs `let cell = cells[0]` on a `Cell[]` field failed `snl check` and `snl build` with ``error[SNOVA0251]: cannot move a value out of an array element or field; borrow it with `&` or build a copy`` at that line; the seed rejected the program with `error[SNV3001]: unsupported construct or invalid lowering at line 23, function #0` (line 23 is the end of `main`, so the seed's location is not exact). SPEC-0001 slices 3–5 depend on both restrictions.
- Change: `BinarySearch` and `LinearSearch` use instance methods; `librarySearch` creates them with `BinarySearch()` and `LinearSearch()`. New gate `make bootstrap-library-root` joins each fixture with the instance-API modules only. It also compares stdout and exit status with `bootstrap/fixtures/expected/librarySearch.stdout` and `.status`, captured from the fixture and library of `2fba2df` (before the migration) compiled by the Snova compiler, where `snl run-snbc` and the Snova executor agreed (exit 53).
- Commands: `make bootstrap-library-root`; the SnBC half of `bootstrap-library` (check, Snova compiler, `snl run-snbc` against the Snova executor) for all five library fixtures, run by hand; `make bootstrap-fixed-point bootstrap-vm`; native emission (`<joined.snl> <out.s> native`) for `librarySearch`; `sh scripts/hooks/validate-planning-docs.sh`; `git diff --check`.
- Observed result: in `bootstrap-library-root`, the `snl build` executable, `snl run-snbc` and the Snova executor agreed on stdout and exit status 53 for `librarySearch`, and matched the committed expected files (`4 -1 1 3 7 true -1 1 3 2 4 -1`, one value per line). With one line of the expected stdout altered, and separately with the expected status set to 54, the gate failed. SHA-256 of `librarySearch.root.snbc`: `7f90b57a8be915849b7f258bde8483fb787a699c8005b0cd9a88fba8c33830e9`. The SnBC half of `bootstrap-library` passed for all five fixtures (exits 53, 204, 73, 12, 104). The fixed point and the executor differential still pass. The native backend emitted assembly for `librarySearch` without errors.
- Not verified: the native half of `bootstrap-library` (assembly, link, run, zero live blocks) for the changed fixture, which needs the aarch64-apple-darwin host. The compiler does not use the library yet.
- Limitations: only stateless types are migrated. `Sorting`, `IntCell`/`IntArray`, `BinaryHeap`, `BinaryTree` and `IntMap` still use static methods and are not built by `snl build`; stateful types also have to respect the other root rules (no method calls on fields, no shared arrays between fields).
