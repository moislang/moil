# ADR-0005 — Native aarch64-apple-darwin backend in Snova

- **Status:** Accepted; slices N1, N2 and N3 implemented (see "State")
- **Date:** 2026-11-21

## Context

The executable produced by `snl build` is not the program's machine code.
Observation from 2026-11-21: `snl build` generates SnBC and bundles the `snl`
C VM (`run_function` dominates the profile). The build message itself says
"bundled binary dependencies", and the SnBC lowering rejects constructs that
the checker accepts. So the Snova SnBC executor runs on top of another VM:
there are two interpretation layers, and self-compilation through the Snova
VM takes minutes.

The project requires native compilation of Snovalang: the Snova compiler must
emit host machine code for programs and for itself, with no embedded C VM and
no `snovac`.

Probe recorded in `evidence.md`: on the `arm64` host, an assembly `main`
assembled with `as` and linked with `ld -lSystem` runs and returns 48. `ld`
applies an ad-hoc signature (`flags=adhoc,linker-signed`), which the kernel
requires for arm64 executables.

## Proposal

Single initial target: `aarch64-apple-darwin`, Mach-O, AAPCS64, linked
against `libSystem`. Vertical slices, each with its own gate:

1. **N1 — numeric.** A Snova backend that translates the current lowering
   (functions, locals, arithmetic, comparisons, jumps, calls, return) into
   textual assembly. Gate: `numericVm`, `numericFlow` and `nativeCalls`
   (calls, recursion, division/remainder by zero, shifts, negation) return the
   same exit status as the Snova executor and `run-snbc`. In this slice the
   system `as`/`ld` are assembly and link tools, not compiler implementation.
2. **N2 — runtime in Snova.** Allocation, arrays, structs, strings, printing,
   files, arguments and environment, written in Snova and compiled by the
   backend itself. Assembly only for `libSystem` calls (for example `write`,
   `read`, `open`, `mmap`, `exit`), each with an ABI contract, registers and
   test (ADR-0003). This boundary also resolves the string→bytes conversion
   pending in ADR-0004. Details and the ownership model are in ADR-0006.
3. **N3 — native compiler.** The compiler compiles its own sources to a
   native executable, and that executable repeats the compilation. The fixed
   point is checked on the emitted assembly; the Mach-O carries a UUID and a
   signature and needs a normalization policy (ADR-0002).
4. **N4 — no external toolchain (optional, separate ADR).** A Mach-O writer
   and ad-hoc signing in Snova, removing `as`/`ld`.

## State

N1, N2 and N3 are implemented in `bootstrap/src/native*.snl` and
`bootstrap/runtime/*.snl`. `make bootstrap-native-self` builds the compiler's
ordered source modules with the transitional seed, links a native compiler,
and requires two further native compiler generations to emit identical
assembly. The entry point is
`snova-bootstrap <input.snl> <output.s> native`: the compiler appends the Snova
runtime to the program, generates the SnBC image in memory, validates it and
translates it to assembly. The gate is `make bootstrap-native`.

- Opcodes outside the subset (enum variants, match, async/spawn, doubles,
  globals) make the backend fail with `unsupported opcode for native backend:
  N`.
- Generated code calls only `_write`, `_read`, `_open`, `_close`, `_mmap`,
  `_munmap` and `_exit`, and only from the stubs of the native `Primitive` and `System` methods (ADR-0006).
- Memory is released through ownership: zero live blocks at exit and constant
  peak memory in loops (ADR-0006).
- The operand stack uses 16-byte `(payload, tag)` slots, a simple choice with
  no register allocation yet.
- The third word of the command line is not compared, because the subset does
  not compare host strings.

## Consequences

- `snl build` remains the transitional root for the first native compiler;
  its bootstrap executable is still SnBC bundled with the C VM, not native.
  N3 demonstrates native self-compilation and an assembly fixed point, not an
  independent root or DDC.
- The Snova SnBC executor (ADR-0004) becomes the backend's differential
  oracle, not the distribution path.
- The seed subset does not run processes. Until it has that primitive,
  assembling and linking in N1–N3 are build steps (Makefile).

## Reopen when

Another target is required, the runtime gains process execution, or N4 is
prioritized.
