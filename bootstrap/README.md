# Bootstrap compiler seed

This directory contains the initial Snova implementation of a compiler slice.
It is the first in-repository compiler source, not a complete replacement for
`snovac` yet.

## Build chain

Run `make bootstrap-fixed-point` with the installed `snl` toolchain. The target
builds the multi-file project, asks the Snova compiler to compile its own
sources, then asks the generated compiler to do the same. Both SnBC images must
match byte for byte. The compiler's `sourceJoin.snl` handles this internal
bootstrap operation; there is no separate joiner executable.

Run `make bootstrap-build` to produce `build/bootstrap/snova-bootstrap`, then
invoke it with `<input.snl> <output.snbc>`. With no arguments, it compiles its
own modules and reads the output path from `SNL_OUTPUT`. One `.snbc` argument
validates the canonical image structure, opcodes and instruction references. `make bootstrap-image-check` exercises
both a valid self-compiled image and a truncated one.

`<image.snbc> run [args...]` executes an SnBC image through the executor
written in Snova (`src/vm*.snl`). The mode is recognised by the `SNBC` magic of
the first argument; arguments after `run` belong to the program. The executor
is iterative (256-frame limit), predecodes instructions, and supports typed
values, calls, arrays, objects, byte-backed strings with value equality, file
I/O and the runtime API used by the compiler. Run `make bootstrap-vm` for the
stdout/exit-code differential against `snl run-snbc`, and
`make bootstrap-vm-self` to have the Snova executor run the compiler image and
reproduce `stage1.snbc` byte for byte (it takes minutes: the Snova executor
itself runs on the C VM bundled by `snl build`). Design, intentional
divergences and the provisional string boundary are in
`docs/decisions/ADR-0004-snova-snbc-executor.md`. This is a development
command, not the final CLI.

`<input.snl> <output.s> native` runs the native backend (`src/native*.snl`,
ADR-0005): the compiler appends the Snova runtime (`runtime/*.snl`,
ADR-0006) to the program, and the validated SnBC image becomes
aarch64-apple-darwin assembly. The runtime covers strings, arrays, objects,
printing, files, arguments and environment, and releases memory through
ownership. `make bootstrap-native` assembles and links with the system
`as`/`ld`. It checks stdout and exit status against the Snova executor, zero
live blocks at exit (`SNOVA_MEMORY_REPORT=1`), constant peak memory in a loop
and the rejection of strong cycles. Unsupported opcodes fail with
`unsupported opcode for native backend: N`.

`library/` holds data structures and algorithms in Snova (searches,
sorting, `BinaryHeap`, `BinaryTree`, `IntMap`). `make bootstrap-library`
runs each fixture on `snl run-snbc`, on the Snova executor and natively.

Run `make bootstrap-smoke` to compile and execute the small program in
`fixtures/hello.snl` through the generated SnBC image.

Run `make bootstrap-diagnostics` to check lexer and parser failures include a
phase and source line, and that `==`/`!=` between operands whose static types
are known and different (for example a string literal and an integer, or a
struct and an integer) prints `warning[SNW0001]: comparison between different
types at line N` without stopping compilation. Unknown types (calls, indexing)
do not warn.

`snl` is the temporary seed and supplies the existing runtime. Its `snl build`
output bundles SnBC with the C VM of `snl`; it is not machine code (see
`docs/decisions/ADR-0005-native-backend.md`). The compiler
and its I/O facade are in `.snl`. The generated SnBC compiler still runs through
the previous toolchain, so this is not yet a standalone distribution.

## Current subset

The compiler modules share the `snova.compiler` package where appropriate;
`compiler.snl` imports the `snova.compiler.runtime` and `snova.compiler.backend`
packages, and `make bootstrap-check` validates these cross-file imports. Module declarations
and names follow the project's `camelCase` convention. Every compiler source
file stays below 400 lines.

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
drop-in `snovac`, does not implement the complete Snovalang type system or CLI,
and is not yet compatible with the full `snovac` source tree. Grow it in small
stages: each stage must compile the next stage before that feature is used by
the compiler source.

## Source provenance

The initial seed source was copied from the read-only reference checkout at
`../snovac/bootstrap/src` revision `2b5048aaf221527e22ea844f858b5d0f33f149c9`
on 2026-11-21. The reference checkout was not modified. The copied source is
distributed under Apache License 2.0; see [LICENSE](LICENSE).
