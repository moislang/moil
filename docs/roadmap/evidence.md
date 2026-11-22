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
- Organization at that historical checkpoint: compiler modules in `bootstrap/src/`, functions and types in `camelCase`, files under 400 lines. The current convention is `PascalCase` for types and source files, and `camelCase` for functions, methods and variables. Historical module names in this entry predate the current naming convention.
- Commands: `snl check --project bootstrap/src`, `make bootstrap-smoke`, `make bootstrap-diagnostics`, `make bootstrap-fixed-point`.
- Observed result: cross-package imports and the multi-file project passed the check; smoke test and diagnostics passed; the Snova joiner generated the seed unit, which compiled the sources and reached byte-for-byte equality.
- SHA-256 of the stage 1 and 2 SnBC images: `6dab7126700e6416ade1ba2df110ea8486dc6cae989954d484330a0919c42740`.
- Limitations: the seed does not load modules/imports on its own yet; the temporary joiner strips headers to self-compile. The execution runtime is still the one from `snl`; broad compatibility and a standalone backend were not demonstrated.

## 2026-11-21 — path-based I/O and internal bootstrap assembly

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-fixed-point`, `make bootstrap-smoke`, `make bootstrap-diagnostics`.
- Observed result: the multi-file project binary accepted input/output paths as arguments; without arguments it compiled its own sources through `SourceJoin.snl` and used `SNL_OUTPUT`. The generated SnBC repeated the compilation without the external joiner, and the two images matched byte for byte. Smoke test and diagnostics passed with the new CLI.
- SHA-256 of the two SnBC images: `4d00222c46e427a3308bf1f7ede3935d8a6744222f7d074a2f7ac115b2482716`.
- Limitations: `Runtime.snl` wraps the argument, environment and byte calls, but those primitives and SnBC execution still come from the reference runtime. The internal assembly lists the compiler's own modules; general imports, full semantics, a Snova native backend and full compatibility with `snovac` remain pending.

## 2026-11-21 — structural SnBC reader in Snova

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-image-check`, `make bootstrap-fixed-point`.
- Observed result: `ImageReader.snl` accepted the image produced by the compiler, rejected a truncated image and was compiled as part of the compiler itself in the next generation. The stage 1 and 2 images matched byte for byte.
- SHA-256 of both images: `8ecf10657461d96e7033ed391ba1fdfd60400579e503e36ff7d5dd5cec4952cd`.
- Limitations: validation covers structure, sizes and the main indexes; it did not yet validate instructions/opcodes, did not execute SnBC in Snova and did not replace the reference runtime or backend.

## 2026-11-21 — SnBC instruction validation in Snova

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`.
- Commands: `make bootstrap-fixed-point`, `make bootstrap-image-check`, `make bootstrap-smoke`; images derived from `stage1.snbc` with an invalid opcode and an out-of-image jump were rejected by the Snova compiler.
- Observed result: `ImageCode.snl` checked instruction bounds, the last opcode, string/local/function indexes, arity, runtime calls, jumps and not-yet-implemented opcodes; the stage 1 and 2 images matched byte for byte.
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
- Observed result: `WarnMismatch.snl` compiled with status 0 and two `warning[SNW0001]` diagnostics, at lines 10 (`"seven" == 7`) and 13 (struct `!=` int); `WarnCompare.snl` compiled without diagnostics and returned 7 on the Snova executor. Compiling the compiler's own sources emitted no warnings. All quick gates passed.
- Observed result: the Snova executor ran the compiler image again with the current sources; `stage1.snbc`, `stage2.snbc` and `vm-stage.snbc` matched byte for byte. SHA-256: `e5aa78db2ad50a0898e2eaaea287b6ac6a66a39063a6f3fbc8c259ab4ddef2dc`. Time: 3 min 09 s (187.5 s of CPU). This hash replaced the previous entry's hash as the current state.
- Observed in `snl run-snbc` v0.3.0: in `warnCompare`, `true == (1 < 2)` gives false (status 3), while the Snova executor gives true (status 7). So the gate checks that fixture only through the Snova executor.
- Limitations: the warning only covers known static types (literals, typed locals, parameters, fields); calls and indexing have an unknown type and produce no warning. The span is only the line. Address comparison (`&T`) does not exist in the subset yet.

## 2026-11-21 — native backend N1 (ADR-0005)

- Environment: `snl v0.3.0`, `aarch64-apple-darwin`; `as`/`ld` from the Command Line Tools (`-platform_version macos` = SDK version, `-lSystem`).
- Commands: `make bootstrap-native bootstrap-fixed-point bootstrap-vm bootstrap-diagnostics bootstrap-image-check bootstrap-smoke`, `make bootstrap-vm-self`, `git diff --check`.
- Observed result: the Snova compiler emitted aarch64 assembly for `numericVm`, `numericFlow` and `nativeCalls`; the assembled and linked arm64 Mach-O executables returned 48, 48 and 126, equal to the Snova executor and `snl run-snbc`. `Hello.snl` was refused with `unsupported opcode for native backend: 3`. Two emissions of the same source gave identical `.s` files (SHA-256 of `nativeCalls.s`: `62345b3011b88abbfc36cb0ac6524a5cd76a00b2c05876f6569f63518f67fe4c`).
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

## 2026-11-21 — probe: making `bootstrap/library/` visible to the root build (SPEC-0001, before slice 6)

- Repository revision: `2fba2df` (master), in a scratch worktree; library files from `2fba2df` (static API) and from `mike/library-instance-api` (`BinarySearch`/`LinearSearch` with an instance API, snl#3). Nothing in the repository was changed by the probe.
- Host and OS: Linux 6.12, `x86_64-unknown-linux-gnu`; `snl v0.3.0` from the official Linux release (archive SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`); `SNOVA_HOME` pointed at a scratch directory. Reference for project and dependency rules: `snovac` v0.3.0 `README.md` (read-only).
- Question: `make bootstrap-build` runs `snl build --project bootstrap/src`, which does not see `bootstrap/library/`. How can that build see the library without changing the self-compilation stage?
- Observed result, small probe (an `app/main.snl` with `import snova.library` that calls `BinarySearch().indexOf(...)`, and a `lib/` directory with the instance `BinarySearch.snl`):
  - `snl build --project app` alone, `--project app --project lib` and `snl build app/main.snl lib/BinarySearch.snl` all fail with ``error[SNOVA0050]: package `snova.library` was not found``; the last one also prints `error: build needs a file.snl or project path`. `snl` v0.3.0 has no flag for several source roots.
  - Path dependency (in copies named `appC/` and `libC/`): `snl get ../libC` in `appC/` wrote `mod.sns` (`module appC`, `direct = ["libC@1.0.0"]`) and `mod.lock` (`module "libC" "1.0.0" path "../libC"`). `snl check --project` and `snl build --project` then passed; the executable printed `2` and exited with 3. The dependency directory needs no manifest. The build writes a dependency graph into `$SNOVA_HOME/graph/`; with an empty `SNOVA_HOME` it was rebuilt from `mod.lock` without `snl get`.
  - Staging directory: copying `app/*.snl` and `lib/*.snl` into one directory (flat, or with the library in a `library/` subdirectory) and running `snl build --project` on it passed with the same output and exit.
  - Symbolic link `app/library -> ../lib`: `snl build --project app` passed with the same output and exit.
- Observed result, compiler project (`bootstrap/src/` plus library files, library not called by the compiler):
  - Every library module in a `snl build` project is lowered, even when nothing calls it. With the whole `bootstrap/library/` of `2fba2df` visible (staging copy, symbolic link `bootstrap/src/library -> ../library`, or path dependency `snl get ../library`), `snl build` failed with 19 × `error[SNOVA0400]: cannot lower call to SnBC`, 27 × `error[SNOVA0400]: cannot lower field to SnBC` and 2 × `error[SNOVA0400]: cannot lower assignment to SnBC`, then `error: failed to emit bytecode for project ...`. With only the static `BinarySearch.snl` and `LinearSearch.snl` of `2fba2df`, it failed with `error: invalid SnBC unit for native compilation` (a small project with one unused static module did build, so this is not a general rule).
  - With only the instance-API `BinarySearch.snl` and `LinearSearch.snl` of snl#3, both a staging directory (`bootstrap/src/*.snl` plus `library/`) and a path dependency (`mod.sns`/`mod.lock` in `bootstrap/src/` pointing at a directory holding those two files) built. The executable's self-compilation image (`SNL_OUTPUT=...`) had SHA-256 `8cb80e985dbf2f5d087098fa02960e184d38ac540ffc39d936201404c5f730ad`, equal to the baseline `snl build --project bootstrap/src` image.
  - Two `snl build` runs on the same unchanged inputs (baseline project and staging directory alike) produced executables that differ in one byte; the self-compiled SnBC images were identical. The `snl build` executable is not a reproducible artifact; the SnBC image is.
- Comparison:
  - Several roots or several input files: not supported by `snl` v0.3.0.
  - Path dependency: native to `snl`, relative paths, no copies; but the dependency directory must contain only modules the root can lower, so `bootstrap/library/` is usable only after SPEC-0001 slices 2–5. It adds `mod.sns`/`mod.lock` to `bootstrap/src/` and a cache in `$SNOVA_HOME`. The seed and `SourceJoin.snl` ignore both files.
  - Symbolic link: works on Linux, but exposes the whole library (same restriction) and is unreliable on Windows checkouts.
  - Staging directory: works today, chooses modules by an explicit list (like `LIBRARY_ROOT_SOURCES` and the ordered list in `SourceJoin.snl`), needs no repository layout change, no global cache and no links, and uses only `mkdir`/`cp` like the rest of the Makefile.
- Conclusion: a generated staging directory under `build/`, filled from `bootstrap/src/*.snl` and an explicit list of migrated library modules, is the way for the root to see the library during SPEC-0001 slices 2–6. Adding the library leaves the self-compilation image unchanged while the compiler does not call it. Once every library module can be lowered by the root, a path dependency on `bootstrap/library/` becomes possible and should be probed again. Either way, `SourceJoin.snl` must list the same library modules when the compiler starts to use them, and the fixed point checks that.
- Not verified: a compiler module that calls the library (slice 6); `SourceJoin.snl` with library modules; Windows and macOS hosts; `snl build` with `--offline-cache`.

## 2026-11-21 — own root slice 1: committed SnBC seed (ADR-0009, proposed)

- Repository revision: branch `mike/seed-snbc-stage1` on top of `2fba2df`; `bootstrap/src/` unchanged.
- Host and OS: Linux 6.12, `x86_64-unknown-linux-gnu`.
- Reference: `snl v0.3.0` from the official `snovac-linux-x86_64.tar.gz` release (archive SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`), not on `PATH`, passed as `SNL=`.
- Commands: `make bootstrap-seed-refresh`; `make bootstrap-fixed-point bootstrap-seed-fixed-point` from an empty `build/`; `make bootstrap-seed-stage` with an `SNL` wrapper that exits with an error for `check` and `build`; `make bootstrap-seed-stage` with one byte of the seed altered; `sh scripts/hooks/validate-planning-docs.sh`; `git diff --check`.
- Observed result: the seed run by `snl run-snbc` compiled the sources into `seed-stage1.snbc`, which compiled them into an identical `seed-stage2.snbc`; `seed-stage1.snbc` was byte-for-byte equal to `stage1.snbc` from the `snl build` path, and `stage1.snbc` equalled `stage2.snbc`. The seed chain passed with the wrapper that forbids `snl check`/`snl build` (the same wrapper made `bootstrap-build` fail, so the wrapper works). An altered seed was rejected by the hash check before execution. Documentation validation and `git diff --check` passed.
- Probe: an image produced from `HEAD~5` of `2fba2df` (SHA-256 `b974d15434a9d01a1dd56f50b5650913b50025a5f3dd80cddf1bd4f758306ec9`), run by `snl run-snbc`, compiled the current sources into the current fixed-point image in one generation.
- Probe: the native backend, run on this host, emitted the compiler's aarch64-apple-darwin assembly (4350137 bytes, SHA-256 `a6a547e492ccae162b979e00a32a0684581e6fe1c118ff37f8f60d8fe38ee985`) identically twice. It was not assembled or run.
- Artifacts/hash: seed, `seed-stage1`, `seed-stage2`, `stage1` and `stage2` SHA-256 `8cb80e985dbf2f5d087098fa02960e184d38ac540ffc39d936201404c5f730ad` (142693 bytes).
- Also passed on this host: `bootstrap-smoke`, `bootstrap-diagnostics`, `bootstrap-image-check`, `bootstrap-vm`. Not run: `bootstrap-vm-self`; native and library gates (they need the aarch64-apple-darwin toolchain).
- Limitations: the seed chain still runs on the `snl` C VM (`run-snbc`), so this is not an own root and not DDC. The `snova-bootstrap` CLI still comes from `snl build`. Equality of the seed with the image produced on `aarch64-apple-darwin` has not been checked. This is not a clean-environment reproducibility claim.

## 2026-11-21 — seed check against the `snl` C VM boolean comparison defect

- Repository revision: branch `mike/seed-snbc-stage1` (ADR-0009 slice 1); `bootstrap/src/` unchanged from `2fba2df`.
- Host and OS: Linux 6.12, `x86_64-unknown-linux-gnu`; `snl v0.3.0` from the official Linux release.
- Context: on this host the `snl` C VM (`snl build` executables and `snl run-snbc`) gives wrong results for some comparisons of a boolean local with a boolean literal (reported in PR #2). The committed seed was produced by the compiler running on that VM.
- Probe (scratch file outside the repository): in a method of a class with a field, `let local = false` followed by `local == false` printed `false` under `snl build` and under `snl run-snbc` (image compiled by the seed), and `true` under `snl run` and under the Snova executor (`snova-bootstrap <image> run`). `local != true`, `!local`, integer comparisons and the same code in free functions gave correct results in every engine. The exact trigger was not isolated.
- Audit: the only boolean-literal comparisons in `bootstrap/src/` are in `VmLoad.snl` and `VmFast.snl` (executor) and in `NativeBackend.snl` and `NativeInstructionEmitter.snl` (native backend). None is in the lexer, parser, emitter, `SourceJoin.snl` or the SnBC writer. Comparisons between boolean expressions that are not literals were not audited.
- Command: `SNL_OUTPUT=build/bootstrap/vm-seed.snbc build/bootstrap/snova-bootstrap bootstrap/seed/compiler.snbc run` (the seed image run by the Snova executor, which gives the correct result in the probe).
- Observed result: exit 0 after 2 min 21 s; `vm-seed.snbc` SHA-256 `8cb80e985dbf2f5d087098fa02960e184d38ac540ffc39d936201404c5f730ad`, byte-for-byte equal to the seed and to `stage1.snbc` from the `snl build` path.
- Conclusion: for the current sources, the SnBC emitted by the compiler is the same whether it runs on the C VM or on the Snova executor, so the defect did not change the seed's output. The seed's own bytes come from a compiler built and run on the affected VM, and they reproduce themselves on the Snova executor.
- Limitations: the Snova executor is itself built by `snl build` and runs on the same C VM; it is a second interpreter of the compiler's SnBC, not an independent root, so this is not DDC. A later source change could reach an affected comparison in the SnBC path; `bootstrap-seed-fixed-point` does not detect that by itself, because both of its chains run on the C VM.

## 2026-11-21 — probes: enum variants, match, doubles and globals

- Environment: `snl v0.3.0` (`snovac-linux-x86_64.tar.gz` from the v0.3.0 release, SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`), host `Linux 6.12 x86_64`.
- Commands: the seed (`make bootstrap-build`) compiled `VmEnumMatch.snl`, `VmVariantValue.snl` and two scratch probes (a `1.5` literal; a top-level `var`); each was also run with `snl run` and, when it compiled, `snl run-snbc`.
- Observed result: the seed lowers unit variants to `VARIANT` (42, payload count 0) and `match` arms to `IS_VARIANT` (43), `EQ` (24), binding stores and a final trap (52). Before this change, both the Snova executor (`runtime error: unsupported opcode 42`) and the native backend (`unsupported opcode for native backend: 43`) rejected them. `snl run` compares variants by name and prints the variant name (`true false true Red Amber`); `snl run-snbc` compares them by identity and prints an empty line (`false false true` and two empty lines). Integer-only enum programs agree on stdout and exit status (147). The seed rejects the double literal (`SNV2001`) and the top-level `var` (`SNV2001`); `snl run` rejects the top-level `var` too (`SNOVA0023`). `snl check` rejects a non-exhaustive `match` with `SNOVA0205`; the seed accepts it and the program traps at run time.
- Limitations: doubles and globals have no frontend lowering, so no fixture can reach a backend; they stay outside this slice.

## 2026-11-21 — unit enum variants and match in the SnBC and native backends

- Environment: as in the previous entry (Linux x86_64; no aarch64-apple-darwin host). Extra tools for checks only: clang 19.1.7 (`-target arm64-apple-macos13`), `aarch64-linux-gnu-gcc` 14.2.0, `qemu-aarch64` 10.0.13.
- Commands: `make bootstrap-smoke bootstrap-diagnostics bootstrap-image-check bootstrap-fixed-point bootstrap-vm`, `make bootstrap-vm-self`, `python3 scripts/validate-planning-docs.py`, `git diff --check`.
- Observed result: all listed targets passed. The `vmEnumMatch` differential against `snl run-snbc` passed (exit 147); `vmVariantValue` printed `true false true Red Amber` with exit 3; `vmMatchNoArm` reported `runtime error: bodyless routine trapped` with status 70. SnBC stage images matched (SHA-256 `e9e0b89ec5f2792945eff6a0ee89fe52603df14dc7ef770dbaf1766701bea192`), and the Snova executor reproduced `stage1.snbc` from the compiler image.
- Native, not executed on the qualified host: the native assembly for the 15 fixtures below assembled for `arm64-apple-macos13` with clang. It was then rewritten to ELF syntax and linked with a translation layer for `_open`/`_mmap` flags. That harness is a scratch tool outside the repository. Under `qemu-aarch64`, `vmEnumMatch` (147), `vmVariantValue` (3), `vmMatchNoArm` (70), and 12 existing fixtures (`numericVm`, `numericFlow`, `nativeCalls`, `hello`, `vmCalls`, `vmComposite`, `vmEquality`, `vmStackOverflow`, `nativeHostIo`, `staticMethods`, `vmArrayPop`, `vmArrayPopString`) matched the Snova executor's stdout and status, with zero live blocks where the gate requires it. This assembly came from the compiler image running on the Snova executor, not from `build/bootstrap/snova-bootstrap`; the next item explains why.
- Host defect found: on `linux-x86_64`, `snl v0.3.0`'s C VM (`snl build` bundles and `snl run-snbc`) gives wrong results for some `x == false` comparisons after earlier calls; `snl run` and the Snova executor give the right ones. Reproducer: a method that runs `if flag { ... }` with `true`, then `let local = false` followed by `local == false`, prints `false`. Because of this, the Linux `snova-bootstrap` binary drops ownership instrumentation and depth checks from functions with locals. Native assembly from that binary is therefore not trustworthy on this host.
- Not verified: `nativeMemory`, `vmHostText` and `nativeCycle` under the harness, `make bootstrap-native` and `make bootstrap-native-self` (they need macOS `as`/`ld`/`xcrun`), Mach-O linking and execution, and the native compiler fixed point. On qemu, the native compiler built from Snova-executor assembly reported `invalid generated SnBC image` for every input. Whether the ELF harness or the host defect causes this is not established. The aarch64-apple-darwin gates still have to run on the qualified host.

## 2026-11-21 — match exhaustiveness on enums (SNV4004)

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box); reference source read from the `snovac` tag `v0.3.0` (`semantic/check_match.c`, `src/parse/parse_type.c`).
- Probe (reference): `snl check` on enum matches. A match with a variant missing and no `_`/binding arm fails with `error[SNOVA0205]: non-exhaustive match on 'Color': missing variant ...`, positioned at the `match` keyword, for statement and expression forms and for local, parameter, field and call subjects. `_` and binding arms are accepted; matches on `int` without a catch-all are not checked.
- Reference defect found: in `v0.3.0` a qualified pattern keeps its full name (`Color.Red`) while the check compares it with the bare member name (`Red`), so every enum match without a catch-all is rejected, even one that covers all variants, always naming the first variant. A bare variant name (`Red ->`) is parsed as a binding, so a match written with bare names is accepted even when a variant is missing. The seed follows the documented rule of `sn_check_match_exhaustiveness` (compare member names, report the first missing variant) and does not copy this defect.
- Correspondence: `SNV4004` corresponds to `SNOVA0205` ([diagnostics.md](diagnostics.md)). Differentials compare the table row and the position, not the literal code.
- Implementation: `MatchCheck.snl` runs after the subject is lowered. When the subject's static type is a known enum and no arm is `_` or a binding, each variant must appear as a variant pattern (qualified or bare known member); otherwise `error[SNV4004]: non-exhaustive match on 'E': missing variant 'V' at line L, span a..b` (the real output quotes the names with backticks) with the `match` keyword span. `emitUnit` no longer overwrites the token of typed diagnostics with the function index.
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (all pass), `make bootstrap-vm-self` (pass, 2 min 23 s), native emission of `nativeCalls`, `nativeMemory`, `nativeHostIo` plus `clang -c -target arm64-apple-macos13` on the result (pass), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Differential on fixtures: `invalidMatchExpression` gives `SNV4004 ... missing variant 'Wait' at line 11, span 130..135`; `snl check` rejects it with `SNOVA0205` at 11:12 (it names `Stop` because of the defect above). `invalidMatchStatement` (bare names, `Go` missing) gives `SNV4004 ... missing variant 'Go' at line 12, span 136..141`; `snl check` accepts it (bare names are bindings there), a recorded divergence. `matchExhaustive` (all variants, `_`, binding, `int` without catch-all, statement form) compiles and returns 42 under `snl run-snbc`; `snl check` rejects its complete qualified matches because of the defect. A probe corpus of ten cases (local, parameter, field, call, bare names, statement, complete, `_`, binding, `int`) agrees with the documented rule except the call subject, which the seed does not check yet.
- Not verified: `make bootstrap-native`, `bootstrap-native-self` and `bootstrap-library` need macOS (`xcrun`, Mach-O); the Snova VM on `master` lacks `VARIANT`/`IS_VARIANT` (added in PR #2), so the positive fixture runs on the `snl` C VM.
- Limitations: function return types are not tracked, so `match f()` is not checked; no arm guards exist in the subset; duplicate or unreachable arms are not reported.

## 2026-11-21 — immutable bindings (SNV4005)

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box).
- Probe (reference): `snl check` rejects with `SNOVA0047` ("`x` is an immutable `let` binding and cannot be reassigned") an assignment to a `let` local (also when declared without an initializer), to a parameter, to a `for` binding, to a `match` binding and through `+=`. Pushing to a `let` array and assigning a field of a `let` object are accepted.
- Implementation: the parser produces node 36 for `let` and keeps node 21 for `var`. Locals carry a mutability flag (`loc_mut`): `var` locals and compiler temporaries are mutable; `let`, parameters and `for`/`match` bindings are not. Assigning to an immutable local fails with `error[SNV4005]: cannot assign to immutable binding at line L, span a..b` at the binding name in the assignment. It corresponds to `SNOVA0047` ([diagnostics.md](diagnostics.md)).
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (pass), `make bootstrap-vm-self` (pass, about 2 min 24 s), the Linux part of `bootstrap-library` (the five joined library fixtures compile, run in the Snova VM and emit native assembly), native emission of `nativeCalls`, `nativeMemory`, `nativeHostIo`, `nativeCycle`, `numericFlow` (pass), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Differential: `invalidImmutableLet`, `invalidImmutableParam` and `invalidImmutableFor` are rejected by both compilers on the same line (seed lines 5, 4, 6; spans 68..69, 60..61, 97..98; reference `SNOVA0047` at 5:11, 4:11, 6:14). `immutableBindings` (a `var` reassigned, a field of a `let` object assigned, a push on a `let` array) returns 42 in the Snova VM and in `snl run`.
- Not verified: `bootstrap-native`, `bootstrap-native-self` and the Mach-O half of `bootstrap-library` need macOS.
- Limitations: compound assignment (`+=`) and block arm bodies are outside the seed subset, so those reference cases are not covered.

## 2026-11-21 — semantic diagnostic gap inventory and statement lines for SNV3001

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box); `snovac` source at tag `v0.3.0` for code meanings.
- Probe: 41 negative programs (one error each) inside the seed subset, run through `snl check`, `snl build` when check passes, and the seed. The result table is the gap inventory in [diagnostics.md](diagnostics.md). Two cases came from the team: a move out of an array element (`SNOVA0251` in check and build) and a method call through a local alias of a field (accepted by check, `SNOVA0400` in build). The seed accepts the alias case and lowers it. On the move case it fails one statement later, with `SNV3001`, because the moved local has an unknown type.
- Finding: before this change `SNV3001` always reported the last line of the input, because `cx.line` held the lexer's final line during lowering. For example, `let cell = cells[0]` followed by a field use reported the closing line of `main`.
- Implementation: every node records the first line of the statement that created it (`nline`, set while parsing the statement). `emitStmt` makes that line current while it lowers the statement, so `SNV3001` names the failing statement. `invalidRuntimeArity` now reports line 6 (was 8) and `invalidStaticCall` line 14 (was 15), which are the failing statements. The undefined name, undefined function, unknown field, unknown method, non-callable and `break`/`continue` cases report the reference's line.
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (pass), `make bootstrap-vm-self` (pass, about 2 min 28 s), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Not verified: macOS native gates.
- Limitations: a failure outside any statement (function signature) still reports the line of the last lowered statement. The function index in `SNV3001` is unchanged.

## 2026-11-21 — call argument counts (SNV4006)

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box).
- Probe (reference): `snl check` reports `SNOVA0131` ("expected N argument(s), found M") for function calls, instance method calls and constructor calls with extra arguments. Before this change the seed emitted a function call with too few arguments, and the validator then rejected the image (`invalid generated SnBC image`). A constructor with an extra argument was accepted.
- Implementation: every user call site (function, static method, instance method through a local or an implicit receiver, async call, `defer`, `pulsar`) compares the argument count with the callee's parameter count before lowering (`fn_ar` includes the receiver; messages show source counts). A positional constructor fails when it has more arguments than the class has fields; fewer arguments still take the field initializers or defaults. The diagnostic is `error[SNV4006]: expected N argument(s), found M at line L, span a..b` at the called name. It corresponds to `SNOVA0131` ([diagnostics.md](diagnostics.md)).
- Differential: `invalidCallArity`, `invalidMethodArity` and `invalidConstructorArity` are rejected by both compilers with the same counts on the same line (seed lines 8, 13, 9; reference 8:15, 13:23, 9:22).
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (pass), `make bootstrap-vm-self` (pass), the Linux part of `bootstrap-library` and native emission of six native fixtures (pass), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Not verified: macOS native gates.
- Limitations: calls through `Runtime.*` keep their own `SNV3001` check. Whether the reference requires every field in a positional constructor is not probed, so the seed only rejects extra arguments.

## 2026-11-21 — seed refresh after the semantic checks (ADR-0009 update flow)

- Repository revision: branch `inhegas/seed-refresh` on top of `600ed17` (`master` after snl#4, #7, #8 and #9); only `bootstrap/seed/` and this log change.
- Host and OS: Linux, `x86_64-unknown-linux-gnu` (shared box); `snl v0.3.0` from the official Linux release.
- Reason: from snl#4 on, `make bootstrap-seed-fixed-point` failed. The seed `8cb80e985dbf2f5d087098fa02960e184d38ac540ffc39d936201404c5f730ad` stopped with `error[SNV3001]: unsupported construct or invalid lowering` while compiling the current sources, because its own source list (`ownSource()` in `SourceJoin.snl`) predates `MatchCheck.snl`. This is the refresh case of step 2 in `bootstrap/seed/README.md`.
- Commands: `make bootstrap-seed-refresh` from an empty `build/`; `make bootstrap-seed-fixed-point`; `SNL_OUTPUT=build/bootstrap/vm-seed.snbc build/bootstrap/snova-bootstrap bootstrap/seed/compiler.snbc run`; `python3 scripts/validate-planning-docs.py`; `git diff --check`.
- Observed result: the new seed (148729 bytes, SHA-256 `cf64d0d31cb50b124af68b7f2dc78b9788f011a149528d36bef7ee4430397706`) passed its hash check; `seed-stage1.snbc` equalled `seed-stage2.snbc` and `stage1.snbc` from the `snl build` path. The seed run by the Snova executor exited with 0 and produced `vm-seed.snbc` with the same SHA-256, as ADR-0009 requires on this host because of the `snl` C VM boolean comparison defect.
- Not verified: equality with an image produced on `aarch64-apple-darwin`; native and library gates (they need macOS).
- Limitations: same as the first seed entry: the seed chain runs on the `snl` C VM, so this is not an own root and not DDC.

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

## 2026-11-21 — probes for the library and borrow-checker specifications

- Repository revision: `2fba2df` (master).
- Host and OS: Linux 6.12, `x86_64-unknown-linux-gnu`; `snl v0.3.0` Linux binary (SHA-256 `47bc06a3106fecf7b94d740e6b53144361153b9c7b6dfd368460396ecb8b68c5`); seed compiler built from `2fba2df` with `snl build --project bootstrap/src`.
- Commands (scratch files outside the repository): `snl check`, `snl build`, the seed (`<input.snl> <output.snbc>`), `snl run-snbc` and the Snova executor (`<image.snbc> run`) on small programs; each library fixture joined as in `bootstrap-library` and built with `snl build`.
- Observed result (library, SPEC-0001): every library fixture fails `snl build`. Joined only with its own modules, `librarySearch`, `librarySorting`, `libraryBinaryTree` and `libraryIntMap` fail with `invalid SnBC unit for native compilation`; `libraryBinaryHeap` fails with 19 × `SNOVA0400 cannot lower call to SnBC`, all on calls through `let store = storage`. Inside a method, `let cell = cells[index]` is rejected by `snl check` with `SNOVA0251`; the seed rejected that program with `SNV3001`. Passing the element to a private method with a typed parameter (`readCell(cells[index])`) instead passed `snl build`; the executable, `snl run-snbc` on the seed's image and the Snova executor all printed `11 20 2` and exited with 0. Methods named `append`, `at`, `put` and `count` were not intercepted.
- Observed result (ownership, SPEC-0002): `snl check` rejects with `SNOVA0240` a use after `var b = a` for an array and for an object, a use after a move inside an `if`, and an assignment followed by a use of a moved local; it rejects `var taken = holder.items` with `SNOVA0251`. It accepts a use after passing an array as a call argument, and uses after copying a string or an int. The seed accepts all of these; for the array use after move, both executors printed `3` and exited with 3. The seed rejects `total(&a)` with `SNV2001` at the `&`, which `snl check` accepts.
- Limitations: point probes on Linux; the `snl v0.3.0` Linux C VM miscompares some `x == false` expressions, so only the Snova executor is independent of that VM. Not repeated on `aarch64-apple-darwin`. The native backend was not run.

## 2026-11-21 — instance API for `Sorting` and staged first-stage project (SPEC-0001 slice 2)

- Repository revision: branch `mike/library-sorting-instance` (snl#10), first written on top of `b7d763e` (snl#3) and then merged with `master` at `a866277`, which contains snl#3 squash-merged and the seed refresh of snl#11.
- Host and OS: Linux 6.12, `x86_64-unknown-linux-gnu`; `snl v0.3.0` from the official Linux release (archive SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`).
- Probe: `librarySorting` joined with the static `Sorting.snl` failed `snl build` with `error: invalid SnBC unit for native compilation`, then `error: native build failed for '...'`.
- Expected output: `bootstrap/fixtures/expected/librarySorting.stdout` and `.status` were captured from the pre-migration fixture and library (`b7d763e`) compiled by the Snova compiler, where `snl run-snbc` and the Snova executor agreed: `-8 -3 0 1 5 5 9 12 `, `true`, `false`, `5`, `0`, `7`, exit 12.
- Change: `sorted`, `isSorted` and the private `sortRange` are instance methods; `librarySorting` creates `Sorting()`. `LIBRARY_ROOT_SOURCES` is `binarySearch linearSearch sorting` and `LIBRARY_ROOT_FIXTURES` is `librarySearch librarySorting`. `bootstrap-check` and `bootstrap-build` now run on `build/bootstrap/root-project/`, staged by the new `bootstrap-root-project` target from `bootstrap/src/*.snl` and `library/` with the modules in `LIBRARY_ROOT_SOURCES` (SPEC-0001, decision 2). `SourceJoin.snl` is unchanged because the compiler does not call the library yet. A new `.gitattributes` exempts `bootstrap/fixtures/expected/*` from whitespace checks, because the expected stdout keeps the fixture's trailing space byte for byte.
- Commands, one at a time from an empty `build/` (repeated after the merge): `make bootstrap-fixed-point`, `make bootstrap-seed-fixed-point`, `make bootstrap-library-root`, `make bootstrap-vm`, `make bootstrap-smoke`, `make bootstrap-diagnostics`; the SnBC half of `bootstrap-library` for all five fixtures by hand, with native assembly emission for each; `sh scripts/hooks/validate-planning-docs.sh`; `git diff --check`.
- Observed result: in `bootstrap-library-root`, the `snl build` executable, `snl run-snbc` and the Snova executor agreed and matched the expected files for `librarySearch` (exit 53) and `librarySorting` (exit 12). SHA-256 of the SnBC images: `librarySearch.root.snbc` `f0996877c37677be1cfeb8a83e80ff3308b1c7b8c74d53e28e0996bae1a63749` (it differs from slice 1 because the fixture is now joined with `Sorting.snl` too), `librarySorting.root.snbc` `2260d20a27d5d7897aae6e1c7a2c58322e0e1d47cff70f031e19a051b6c4eb87`. Before the merge with `a866277`, the staged project gave `stage1.snbc` = `stage2.snbc` SHA-256 `8cb80e985dbf2f5d087098fa02960e184d38ac540ffc39d936201404c5f730ad`, the value of the unstaged build at that revision. After the merge, `make bootstrap-fixed-point bootstrap-seed-fixed-point` with the staged project gave `stage1.snbc`, `stage2.snbc` and `seed-stage1.snbc` SHA-256 `cf64d0d31cb50b124af68b7f2dc78b9788f011a149528d36bef7ee4430397706` (148729 bytes), equal to the committed seed of `a866277`; the staged first stage does not change the self-compilation image. The executor differential, smoke and diagnostics passed. The SnBC half of `bootstrap-library` passed for all five fixtures (exits 53, 204, 73, 12, 104), and native assembly was emitted for each.
- Not verified: the native half of `bootstrap-library` and `make bootstrap-native` (they need aarch64-apple-darwin). Only SnBC hashes are compared; `snl build` executables are not reproducible byte for byte (snl#6).

## 2026-11-21 — call argument types (SNV4007)

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box). Branch `feature/arg-types` on `dba36d4` (`master` after snl#10).
- Probe (reference): `snl check` reports `SNOVA0132` ("argument 1 has the wrong type") at the opening `(` of a function call, a positional constructor, an instance method call and `xs.push` when the argument's known type does not match the parameter or element type. Before this change the seed accepted those programs.
- Implementation: when both types are known, every user call site compares each argument with the corresponding parameter (`par_ty`): functions, static methods, instance methods (through a local or the implicit receiver) and async calls. A positional constructor compares each provided argument with the field type, in field order. `push` compares the element with the receiver's element type when the receiver has a known array type. `T[]` annotations now keep that element type (a known primitive `T` becomes `T-20`; a known struct `T` becomes `T+10000`). The diagnostic is `error[SNV4007]: argument type does not match parameter at line L, span a..b` at the opening `(`. It corresponds to `SNOVA0132` ([diagnostics.md](diagnostics.md)).
- Differential: `invalidArgType`, `invalidConstructorType`, `invalidMethodArgType` and `invalidPushType` are rejected by both compilers on the same line, and the seed span starts at the reference column's byte (seed spans 118..119, 97..98, 235..236 and 80..81; reference 8:17, 8:18, 13:23 and 5:12). The positive `argTypes` fixture (typed function, constructor, method and `push`) compiles and returns 42 under `snl run-snbc` and the Snova executor.
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (pass), `make bootstrap-seed-fixed-point` (pass; the committed seed still compiles these sources), `make bootstrap-vm-self` (pass), the Linux half of `bootstrap-library` and `make bootstrap-library-root` (pass), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Observed result: `stage1.snbc` = `stage2.snbc` = `seed-stage1.snbc` = `seed-stage2.snbc`, SHA-256 `cc5a81fb75e4c0d2798921870e9fb1329f9c1c628b90354181c3ecafb6b18d58`. The committed seed remains `cf64d0d31cb50b124af68b7f2dc78b9788f011a149528d36bef7ee4430397706`.
- Not verified: macOS native gates (`make bootstrap-native bootstrap-native-self` and the native half of `bootstrap-library`).
- Limitations: a call argument or `push` element of unknown type is still accepted. Array literals keep type 0, so `var xs: int[] = [1, 2]` is accepted (declared known, inferred unknown). `Runtime.*` and print builtins are unchanged. After merge, run `make bootstrap-seed-refresh` so the committed seed itself performs `SNV4007`; no new file was added to `ownSource()`, so the current seed already builds these sources.

## 2026-11-21 — native mode after SNV4007 (runtime string types)

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box). Branch `hotfix/native-arg-type` on `34dceb7` (`master` after snl#12).
- Probe: after snl#12, `snova-bootstrap <file> <out.s> native` failed for every program, including `return 3` and `Hello.snl`, with `error[SNV4007]: argument type does not match parameter at line 281, span 10095..10096` (hello: line 284, span 10166..10167). The SnBC path was unaffected. The first site was `Runtime.outputString("runtime error: ")` in the appended `bootstrap/runtime/Runtime.snl`: `appendNativeRuntime` joins the runtime after the user source, and the runtime declared `outputString(text: int)` / `outputStringTo(..., text: int)` while passing string literals (13 calls in `Runtime.snl`, plus two literals in `Value.snl`). `emitArgsChecked` → `typesClash` rejected those calls. `typeFail` counted newlines over the joined buffer, so the line number was past the end of the user file.
- Implementation: `Runtime.outputString` and `outputStringTo` now take `string`. `Runtime.address` takes `string` and still retags the payload as int for address arithmetic. `value.display` prints an already-int string handle with the new `Runtime.outputHandle(text: int)`. The language requires a type on every parameter and has no untyped or union payload, so `Primitive.tagged` keeps `payload: int` even when `address` passes a string; `checkArgType` therefore exempts calls in the appended runtime (`start >= user_end`). `sourceLine` / `user_end` count diagnostic lines in the user prefix, so a residual appendix error is not reported as a line past EOF. `bootstrap-diagnostics` now compiles `Hello.snl` to `.s` with `native` (no assemble/link) and rechecks that `invalidArgType` in native mode still reports `line 8, span 118..119`.
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (pass), `make bootstrap-seed-fixed-point` (pass; the committed seed still compiles these sources), `make bootstrap-vm-self` (pass), the Linux half of `bootstrap-library` (SnBC differential plus native `.s` emission, no macOS link) and `make bootstrap-library-root` (pass), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Observed result: `stage1.snbc` = `stage2.snbc` = `seed-stage1.snbc` = `seed-stage2.snbc`, SHA-256 `dd8b0a74dc3974dfe27d2332365fdf19746bfb7aea3a3694e605f9f39762b211`. The committed seed remains `cf64d0d31cb50b124af68b7f2dc78b9788f011a149528d36bef7ee4430397706`.
- Not verified: macOS native gates (`make bootstrap-native bootstrap-native-self` and the native half of `bootstrap-library`, which assemble and run the `.s`).
- Limitations: the SNV4007 exemption applies only to the joined native runtime, not to user code. After merge, run `make bootstrap-seed-refresh` so the committed seed itself contains this hotfix; no new file was added to `ownSource()`, so the current seed already builds these sources.
## 2026-11-21 — operator and index types (SNV4008, SNV4009)

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box). Branch `feature/operator-types`, rebased onto `hotfix/native-arg-type` (snl#17).
- Probe (reference): `snl check` reports `SNOVA0133` at the operator for `1 + "x"`, `1 < "x"` and `"seven" == 7`, and `SNOVA0134` at unary `-`/`!` and at the opening `[` of a non-`int` index. Before this change the seed accepted those programs; `==`/`!=` between known, different types only produced warning `SNW0001`.
- Implementation: when operand types are known, `+` accepts a pair of `int` or a pair of `string`; other arithmetic and bitwise operators require `int`; `&&`/`||` require `bool`; `==`/`!=` require equal types; `<`/`>`/`<=`/`>=` require `int` (not strings or bools). Unary `-` requires `int`, unary `!` requires `bool`, and an index expression requires `int`. The diagnostics are `error[SNV4008]: operator cannot be applied to these operand types at line L, span a..b` at the operator, and `error[SNV4009]: ...` at the unary operator or the opening `[`. They correspond to `SNOVA0133` and `SNOVA0134` ([diagnostics.md](diagnostics.md)). Successful operators now also set a result type (`int`, `string` or `bool`). `SNW0001` is no longer emitted; `warnMismatch` is rejected with `SNV4008`.
- Differential: `invalidBinaryType`, `invalidCompareType`, `invalidStringOrder`, `invalidBoolOrder`, `warnMismatch`, `invalidUnaryNeg`, `invalidUnaryNot` and `invalidIndexType` are rejected by both compilers on the same line, and the seed span starts at the reference column's byte (`invalidStringOrder` 57..58, `invalidBoolOrder` 58..59). The positive `operatorTypes` fixture compiles and returns 42 under `snl run-snbc` and the Snova executor.
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (pass), `make bootstrap-seed-fixed-point` (pass; the committed seed still compiles these sources), `make bootstrap-vm-self` (pass), the Linux half of `bootstrap-library` and `make bootstrap-library-root` (pass), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Observed result: `stage1.snbc` = `stage2.snbc` = `seed-stage1.snbc` = `seed-stage2.snbc`, SHA-256 `4a5e605eb7bece2828702530e4861cf48ef09f44a9d6710667dd630683ebf9dd`. The committed seed remains `cf64d0d31cb50b124af68b7f2dc78b9788f011a149528d36bef7ee4430397706`.
- Not verified: macOS native gates.
- Limitations: an operand of unknown type is still accepted, except that a known non-`int` or non-`bool` left or right side still fails for operators that require that type. After merge of this stack, run `make bootstrap-seed-refresh`; no new file was added to `ownSource()`.

## 2026-11-21 — non-bool if/while conditions (SNV4010)

- Environment: `snl v0.3.0` official Linux release, `x86_64-unknown-linux-gnu` (shared box). Branch `feature/nonbool-condition`, rebased onto `feature/operator-types` (snl#13) after the native hotfix (snl#17).
- Probe (reference): `snl check` reports `SNOVA0135` ("condition must be `bool`") at the start of a known non-`bool` `if` or `while` condition. Before this change the seed accepted those programs.
- Implementation: after the condition is typed, a known non-`bool` type fails with `error[SNV4010]: condition must be bool at line L, span a..b` at the start of the condition expression. It corresponds to `SNOVA0135` ([diagnostics.md](diagnostics.md)). A condition of unknown type is still accepted.
- Differential: `invalidIfCondition` and `invalidWhileCondition` are rejected by both compilers on the same line, and the seed span starts at the reference column's byte (seed spans 72..73 and 75..76; reference 5:8 and 5:11). The positive `boolConditions` fixture compiles and returns 42 under `snl run-snbc` and the Snova executor.
- Commands: `make bootstrap-diagnostics bootstrap-smoke bootstrap-image-check bootstrap-fixed-point bootstrap-vm` (pass), `make bootstrap-seed-fixed-point` (pass; the committed seed still compiles these sources), `make bootstrap-vm-self` (pass), the Linux half of `bootstrap-library` and `make bootstrap-library-root` (pass), `sh scripts/hooks/validate-planning-docs.sh`, `git diff --check`.
- Observed result: `stage1.snbc` = `stage2.snbc` = `seed-stage1.snbc` = `seed-stage2.snbc`, SHA-256 `8354ca44e7b1fe96b0137255477eb7438d3d728732b5d330f0b27543f8a31b08`. The committed seed remains `cf64d0d31cb50b124af68b7f2dc78b9788f011a149528d36bef7ee4430397706`.
- Not verified: macOS native gates.
- Limitations: only `if` and `while` are checked. After merge of this stack, run `make bootstrap-seed-refresh`; no new file was added to `ownSource()`.

## 2026-11-22 — contract diagnostic renumbered to SNV4012

- Environment: `snl v0.3.0` (`snl --version`), macOS ARM64. Branch `feat/snl-docs-linux-bootstrap`.
- Reason: `SNV5001` is reserved for use of a moved value (`SNOVA0240`, SPEC-0002), which the borrow checker (#19) emits. The interface/trait contract failure now reports `SNV4012`; its internal error phase is 30.
- Probe (reference): `snl check bootstrap/fixtures/<name>.snl` reports nothing for `InterfaceMissingMethod` and `InterfaceWrongSignature`, and `error[SNOVA0102]: expected a declaration, found identifier` at line 10 for `TraitMissingMethod` and `TraitWrongArity`. There is no reference code to match.
- Commands: `make bootstrap-build` then `make -j1 bootstrap-smoke bootstrap-fixed-point bootstrap-vm bootstrap-oop` (pass).
- Not verified: Windows CLI jobs (they still fail on `VmHostText` with `cannot write file`).

## 2026-11-22 — Windows VM scratch file outside /tmp

- Probe (Windows x86_64 CI, run of `355b6b0`): `VmHostText` failed with `cannot write file: No such file or directory` and no stdout for an unset `SNOVA_FIXTURE_OUTPUT`, an absolute Windows path and a backslash path alike. The failing write was not the fixture's: `vmStringStart` in `VmString.snl` converts host strings to bytes through the fixed scratch file `/tmp/snova-vm-string.bin`, and a native Windows executable has no `/tmp`.
- Change: the scratch directory is `TEMP`, then `TMP`, then `TMPDIR`, then `/tmp`.
- Probe (macOS, `snl v0.3.0` bundle): with `TEMP`, `TMP` and `TMPDIR` unset the fixture passes through `/tmp`; with `TEMP` set to a directory it passes; with `TEMP=` (set but empty) the path becomes `/snova-vm-string.bin` and the write fails, because the seed compares that host string by identity, not content. An unset variable compares equal to `""`.
- Commands (macOS): `make -j1 bootstrap-smoke bootstrap-fixed-point bootstrap-vm bootstrap-oop bootstrap-target-cli bootstrap-diagnostics`, `make bootstrap-native`, `make bootstrap-native-target` (pass).
- Not verified at commit time: Windows CI with the fix, `bootstrap-vm-self`, the Linux container.

## 2026-11-22 — native target selection on the command line (`--target`)

- Environment: macOS ARM64 with `snl v0.3.0` (`snl --version`); Linux AArch64 in `ci/linux-aarch64.Dockerfile` (`snova-linux-aarch64:ci`, seed `snovac` at `2b5048aa`), run through Docker on the same Mac. Branch `feat/snl-docs-linux-bootstrap`.
- Implementation: the compiler accepts `<in.snl> <out.s> --target <triple>`, `native --target <triple>`, `native <triple>` and `native` (default `aarch64-apple-darwin`). Any other native-mode command line exits 2 with the usage text. The triple selects the format: Mach-O for `aarch64-apple-darwin`, ELF for `aarch64-unknown-linux-gnu`; `x86_64-unknown-linux-gnu` still fails with "backend is not implemented". `make` takes `NATIVE_TARGET=<triple>`; CI takes the `native_target` input of `workflow_dispatch`.
- Commands (macOS): `make -j1 bootstrap-smoke bootstrap-fixed-point bootstrap-vm bootstrap-oop bootstrap-target-cli` (pass), `make bootstrap-native-target` (pass; stage1.s = stage2.s = stage3.s for `aarch64-apple-darwin`).
- Commands (Linux AArch64): `make bootstrap-cli-linux-aarch64` (pass): `bootstrap-target-cli`, the 13 ELF fixtures against the SnBC VM, and `bootstrap-native-self-target NATIVE_TARGET=aarch64-unknown-linux-gnu`, whose native `snl` gives stage2.s = stage3.s.
- Observed divergence: on Linux AArch64, stage1.s produced by the SnBC compiler under the seed VM has 275,508 lines and 8 stack-depth checks; stage2.s produced by the native compiler has 528,181 lines and 475 checks, the same shape as the macOS stage 1 (528,164 lines, 475 checks). On macOS stage 1 and stage 2 are identical. The old Linux gate compiled only fixtures and did not compare these files. The cause is not identified; `NATIVE_STAGE1_CHECK=report` turns this comparison into a warning for the Linux target only, while stage2 = stage3 stays mandatory.
- Not verified: hosted CI runners for these targets; the Linux x86-64 and Windows native formats (no backend).

## 2026-11-22 — CI root is the official snl v0.3.0 binary

- Change: CI no longer compiles `snovac` from source. `.github/actions/setup-snl` downloads the official `snl` v0.3.0 release (`snovalang/snovac` tag `v0.3.0`, commit `590a490d`, which contains the former pin `2b5048aa`) and checks its SHA-256: `6ddee0ca…acf8b` (darwin-aarch64), `f7d39f96…8ed8f8` (linux-x86_64), `6400c05f…b4988` (windows-x86_64). Only these platforms have an official binary, so CI runs Linux x86_64, macOS ARM64 and Windows x86_64; Windows ARM64 and macOS x86_64 left CI. Linux ARM64 runs without `snl`: the Linux x86_64 job emits the ELF fixtures, the compiler's stage 1 and the expected VM results (`make bootstrap-native-linux-aarch64-emit`), and an ARM64 runner assembles, links and runs them (`make bootstrap-native-linux-aarch64-run`). A newer push cancels the previous run of the same PR.
- Observed durations (run of `15811f5`): Linux x86_64 30 s, Windows x86_64 63 s, macOS ARM64 111 s (with the native Darwin build), Windows MSI build and install test 85 s; Windows ARM64 used to take about 27 minutes.
- Stage 1 divergence, refined: emitted on macOS ARM64 (official `snl` v0.3.0) and run on Linux AArch64, stage1.s = stage2.s = stage3.s. Emitted on Linux x86_64 (official v0.3.0, CI) or Linux AArch64 (seed built from `2b5048aa`), stage1.s differs from stage2.s from line 42 (missing stack-depth checks). The divergence follows the Linux host that runs the SnBC compiler, so code generation depends on the host; the cause is not identified. `NATIVE_STAGE1_CHECK=report` keeps it a warning for the Linux target; stage 2 = stage 3 stays mandatory.
- Line endings: `.gitattributes` checks out text as LF on every platform (see the Windows entry).
- Not verified: the local Docker targets (`bootstrap-cli-linux-*`) still build `snovac` from source; CI does not use them.
- Follow-up: macOS x86_64 and Windows ARM64 run in `.github/workflows/extended-platforms.yml`, weekly and on demand (`gh workflow run extended-platforms.yml`), with the seed built from `snovac` at `590a490d` (the v0.3.0 tag) and cached per platform. Pull requests do not run them.

## 2026-11-21 — instance API for `IntCell` and `IntArray` (SPEC-0001 slice 3)

- Repository revision: branch `mike/library-intcell-intarray` on `master` at `34dceb7` (after snl#10 and snl#12).
- Host and OS: Linux 6.12, `x86_64-unknown-linux-gnu` (shared box); `snl v0.3.0` from the official Linux release (archive SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`).
- Probe: a single-file program with the instance `IntCell` (``IntCell(value)``, ``read()``, ``assign(newValue)``) and an `IntArray` that reaches cells through private ``readCell(cell: IntCell)``/``assignCell(cell: IntCell, newValue: int)`` passed `snl check`; the `snl build` executable, `snl run-snbc` and the Snova executor printed the same lines and exited 32. `count`, `isEmpty`, `at`, `put`, `append`, `removeLast`, `swap` and `values` are not intercepted as array builtins. Static methods are still rejected by `snl build` (slice 2), so `IntCell` loses its static `read`/`assign`.
- Expected output: the new fixture `libraryIntArray` (empty `isEmpty`/`removeLast`/`at`/`put`, out-of-range `at` and `put` on both sides, `swap`, reuse of a removed cell, `values`) was first written with ``IntArray { cells: cells, size: 0 }`` and joined with the pre-migration library at `34dceb7`; `snl run-snbc` and the Snova executor agreed, exit 53. That output is committed as `bootstrap/fixtures/expected/libraryIntArray.stdout` and `.status`. The same run recorded the full stdout of `libraryBinaryHeap` (exit 204) and `libraryIntMap` (exit 104).
- Change: `IntCell.read`/`assign` are instance methods; `IntArray` uses `readCell`/`assignCell` and pushes ``IntCell(newValue)``; `IntMap` uses `readHead`/`assignHead` for its bucket heads (its `MapEntry` accessors stay static until slice 5). `libraryIntArray` creates ``IntArray(cells, 0)``. `LIBRARY_ROOT_SOURCES` is `intCell intArray binarySearch linearSearch sorting` (dependency order, as in `LIBRARY_SOURCES`); `LIBRARY_ROOT_FIXTURES` and `LIBRARY_FIXTURES` gain `libraryIntArray`. `bootstrap/src/` is unchanged.
- Commands, one at a time from an empty `build/`: `make bootstrap-library-root`, `make bootstrap-fixed-point`, `make bootstrap-seed-fixed-point`, `make bootstrap-vm`, `make bootstrap-smoke`, `make bootstrap-diagnostics`; `make bootstrap-fixed-point` again on `34dceb7` without the change; the SnBC half of `bootstrap-library` for all six fixtures by hand; `sh scripts/hooks/validate-planning-docs.sh`; `git diff --check`.
- Observed result: in `bootstrap-library-root`, the `snl build` executable, `snl run-snbc` and the Snova executor agreed and matched the expected files for `librarySearch` (exit 53), `librarySorting` (exit 12) and `libraryIntArray` (exit 53). SHA-256 of the SnBC images: `librarySearch.root.snbc` `8a4f12eaddcb5f340c93e2f20de2efea601739259d647e6f3c4570355ccc4d56`, `librarySorting.root.snbc` `2b95a104dff055dbbdea6b53bc92c02d948cf351d470e295a5f1e53cedbe37cd` (both differ from slice 2 because the fixtures are now joined with `intCell.snl` and `intArray.snl` too), `libraryIntArray.root.snbc` `dbd7390d92054733bc8bdc98d4f8cd31a2b638a4a64338da3e109d879e5ce174`. `stage1.snbc` = `stage2.snbc` = `seed-stage1.snbc` SHA-256 `cc5a81fb75e4c0d2798921870e9fb1329f9c1c628b90354181c3ecafb6b18d58`, equal to `stage1.snbc` of `34dceb7` without the change. The executor differential, smoke and diagnostics passed. The SnBC half of `bootstrap-library` passed for all six fixtures (exits 53, 204, 73, 12, 104, 53); `libraryBinaryHeap`, `libraryIntMap` and `libraryIntArray` printed the same stdout as before the migration.
- Not verified: the native half of `bootstrap-library` and `make bootstrap-native` (they need aarch64-apple-darwin). At `34dceb7`, with or without this change, native assembly emission (``snova-bootstrap <file> <out.s> native``) fails for every program tried, including a trivial ``return 3``, with ``error[SNV4007]: argument type does not match parameter`` at a line past the end of the input file, so the macOS native gates are expected to fail on `master` until that is fixed. Only SnBC hashes are compared (snl#6).
