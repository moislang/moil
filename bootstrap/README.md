# Bootstrap compiler seed

This directory contains the initial Mois implementation of a compiler slice.
It is the first in-repository compiler source, not a complete replacement for
`moisc` yet.

## Build chain

Run `make bootstrap-fixed-point` with the installed `moil` toolchain. The target
builds the multi-file project, asks the Mois compiler to compile its own
sources, then asks the generated compiler to do the same. Both SnBC images must
match byte for byte. The compiler's `SourceJoin.moi` handles this internal
bootstrap operation; there is no separate joiner executable.

`seed/compiler.mlbc` is a committed SnBC seed (ADR-0009, proposed). `make
bootstrap-seed-fixed-point` runs it with `moil run-snbc` only, checks that the
next two images match, and compares the first one with the `moil build` path.
See `seed/README.md` for provenance and the update flow.

Run `make bootstrap-build` to produce `build/bootstrap/moil`, then
invoke it with `<input.moi> <output.mlbc>`. With no arguments, it compiles its
own modules and reads the output path from `SNL_OUTPUT`. One `.mlbc` argument
validates the canonical image structure, opcodes and instruction references. `make bootstrap-image-check` exercises
both a valid self-compiled image and a truncated one.

`<image.mlbc> run [args...]` executes an SnBC image through the executor
written in Mois (`src/Vm*.moi`). The mode is recognised by the `SNBC` magic of
the first argument; arguments after `run` belong to the program. The executor
is iterative (256-frame limit), predecodes instructions, and supports typed
values, calls, arrays, objects, byte-backed strings with value equality, file
I/O and the runtime API used by the compiler. Run `make bootstrap-vm` for the
stdout/exit-code differential against `moil run-snbc`, and
`make bootstrap-vm-self` to have the Mois executor run the compiler image and
reproduce `stage1.mlbc` byte for byte (it takes minutes: the Mois executor
itself runs on the C VM bundled by `moil build`). Design, intentional
divergences and the provisional string boundary are in
`docs/decisions/ADR-0004-mois-snbc-executor.md`. This is a development
command, not the final CLI.

`<input.moi> <output.s> native` runs the native backend (`src/Native*.moi`,
ADR-0005): the compiler appends the Mois runtime (`runtime/*.moi`,
ADR-0006) to the program. By default the validated image becomes
aarch64-apple-darwin assembly; passing `aarch64-unknown-linux-gnu` selects the
Linux ARM64 ELF entry and syscall runtime. The runtime covers strings, arrays,
objects, printing, files, arguments and environment, and releases memory
through ownership. `make bootstrap-native` assembles and links Darwin with the
system `as`/`ld`. `make bootstrap-cli-linux-aarch64` builds and tests inside
the pinned ARM64 Docker image, including the CLI/VM gates and native ELF
differential fixtures. `make bootstrap-cli-linux-x86_64` tests the CLI/VM on
Linux x86_64; its native emitter is not implemented. The Linux ARM64 gate
checks stdout and exit status against the Mois executor, zero
live blocks at exit (`MOIS_MEMORY_REPORT=1`), constant peak memory in a loop
and the rejection of strong cycles. Unsupported opcodes fail with
`unsupported opcode for native backend: N`.

`library/` groups Mois code by domain: `algorithms/search`,
`algorithms/sorting`, and the collection aggregates under `collections/`
(`array`, `heap`, `tree`, `map`). `BinaryTree` owns its node arena and
`IntMap` owns its entry and bucket storage; their entity types keep their
behavior behind instance methods. `make bootstrap-library`
runs each fixture on `moil run-snbc`, on the Mois executor and natively.
The library exposes instance APIs (ADR-0007, SPEC-0001), so
`make bootstrap-library-root` also builds the root-compatible fixtures with `moil build` and
compares that executable with `moil run-snbc`, the Mois executor and the
expected output in `fixtures/expected/` (stdout and exit status captured
before the migration); it needs no native toolchain. Those modules are also
copied into the first-stage project: `make bootstrap-build` runs `moil build`
on `build/bootstrap/root-project/`, staged from `src/*.moi` plus the modules
in `LIBRARY_ROOT_SOURCES`, preserving each package folder, because `moil` v0.3.0 builds one project directory
and lowers every module it sees.

Run `make bootstrap-smoke` to compile and execute the small program in
`fixtures/Hello.moi` through the generated SnBC image.

Run `make bootstrap-diagnostics` to check lexer and parser failures include a
phase and source line, and that `==`/`!=` between operands whose static types
are known and different (for example a string literal and an integer, or a
struct and an integer) prints `warning[SNW0001]: comparison between different
types at line N` without stopping compilation. Unknown types (calls, indexing)
do not warn.

`moil` is the temporary seed and supplies the existing runtime. Its `moil build`
output bundles SnBC with the C VM of `moil`; it is not machine code (see
`docs/decisions/ADR-0005-native-backend.md`). The compiler
and its I/O facade are in `.moi`. The generated SnBC compiler still runs through
the previous toolchain, so this is not yet a standalone distribution.

## Current subset

The compiler modules share the `mois.compiler` package where appropriate;
`Compiler.moi` imports the `mois.compiler.runtime` and `mois.compiler.backend`
packages, and `make bootstrap-check` validates these cross-file imports. Module
declarations and source file names use `PascalCase`; types use `PascalCase`, and
functions, methods and variables use `camelCase`. Every compiler source file
stays below 400 lines.

The seed recognizes and lowers a small imperative subset: functions, structs,
classes with instance and `static` methods (ADR-0007), integer and string
literals, local bindings, calls, the `Runtime`
methods `environment`, `argumentCount`, `argument`, `writeText`, `fileExists` and
`readText`, arithmetic and comparison,
short circuit operators, `if`, `while`, and basic returns. Its lexer, parser,
scope lowering, SnBC writer and runtime facade are split into package modules
in `src/`. The compiler internally flattens its own modules for the current
single-source seed interface.

The seed reports failure for constructs outside its subset. It is not a
drop-in `moisc`, does not implement the complete Moislang type system or CLI,
and is not yet compatible with the full `moisc` source tree. Grow it in small
stages: each stage must compile the next stage before that feature is used by
the compiler source.

## Source provenance

The initial seed source was copied from the read-only reference checkout at
`../moisc/bootstrap/src` revision `2b5048aaf221527e22ea844f858b5d0f33f149c9`
on 2026-11-21. The reference checkout was not modified. The copied source is
distributed under Apache License 2.0; see [LICENSE](LICENSE).
