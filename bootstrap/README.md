# Bootstrap compiler seed

This directory contains the initial Snova implementation of a compiler slice.
It is the first in-repository compiler source, not a complete replacement for
`snovac` yet.

## Build chain

Run `make bootstrap-fixed-point` with the installed `snl` toolchain. The target
uses `tools/join.snl` to combine source modules, checks the multi-file project
and natively builds the Snova compiler, asks that compiler to compile its own
joined source to SnBC, then asks the generated
compiler to compile the same source again. It succeeds only if both SnBC images
match byte for byte.

Run `make bootstrap-smoke` to compile and execute the small program in
`fixtures/hello.snl` through the generated SnBC image.

Run `make bootstrap-diagnostics` to check lexer and parser failures include a
phase and source line.

`snl` is the temporary seed and supplies the existing runtime. The compiler
logic being developed here is in `.snl`; no C or C++ implementation is added to
this repository. The generated SnBC compiler still runs on `snl`'s runtime, so
this is not yet a standalone Snova compiler distribution.

## Current subset

The compiler modules share the `snova.compiler` package where appropriate.
`api.snl` exports a public function, and `apiConsumer.snl` imports that module;
`make bootstrap-check` validates these cross-file imports. Module declarations
and names follow the project's `camelCase` convention. Every compiler source
file stays below 400 lines.

The seed recognizes and lowers a small imperative subset: functions, structs,
integer and string literals, local bindings, calls, arithmetic and comparison,
short circuit operators, `if`, `while`, and basic returns. Its lexer, parser,
scope lowering and SnBC writer are split into package modules in `src/`. The
temporary joiner strips each package declaration and combines those parts for
the current single-file seed interface.

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
