# ADR-0004 — Iterative SnBC executor in Snova and value equality

- **Status:** Accepted for the executor. The string→bytes boundary is resolved
  on the native path (ADR-0006); the executor keeps the provisional boundary
  while it runs on the `snl` C VM (see "Provisional boundary").
- **Date:** 2026-11-21

## Context

The seed compiler generates SnBC images that only `snl run-snbc` could
execute. The Snova executor must run the compiler's own image and stay
compilable by the seed. The probes recorded in `evidence.md` showed that:

- `snl run-snbc` v0.3.0 rejects the SET_INDEX opcode (41), and the seed
  subset has no `a[i] = v`; the available mutation is SET_FIELD on structs;
- `snl build` also generates SnBC and embeds the C VM; its lowering rejects
  `a[i].field`, and every host function call costs a frame of that VM;
- the host C VM limits call depth (`error: call depth exceeded`);
- `==` on strings in `snl` v0.3.0 compares identity, while
  `snovac/runtime/value/value_equal.c` defines structural equality.

## Decision

1. Guest values are `(tag, value)` pairs kept in cells (`vmCell`), mutated
   through typed parameters. Guest arrays are `vmArray` structs whose tags are
   materialized only when a non-integer element appears.
2. Instructions are predecoded at load time (`vmDecode.snl`): opcode,
   operands and jump targets are already resolved to instruction indexes.
3. The loop (`vmFrame.snl`) is iterative: CALL saves the frame in `vm.frames`
   and RETURN restores it. The 256-frame limit follows the reference's
   `SN_VM_FRAMES_MAX` and does not depend on the host stack.
4. `==`/`!=` compare values: strings by bytes, and arrays/objects field by
   field, with visited pairs to end cycles. Address comparison (`&T == &E`)
   has no SnBC representation yet and is outside this ADR.
5. The execution mode is recognized by the `SNBC` magic of the first
   argument: `snova-bootstrap <image.snbc> run [args...]`. The arguments after
   `run` belong to the program. The seed does not compare the word `run` yet.

## Provisional boundary

Host strings (`Runtime.environment`, `Runtime.argument`) carry no bytes, and
the seed subset cannot convert a string into bytes. When one of them takes
part in equality or concatenation, `vmString.snl` writes the text with
`Runtime.writeText` to `/tmp/snova-vm-string.bin` and reads the bytes back
with `read_bytes`. Risks: concurrent runs share the file, and the VM depends
on a writable `/tmp`. Running the compiler image never takes this path.

Resolution: the native runtime (ADR-0006) treats every string as bytes,
copying arguments and environment from `argv`/`envp`. Programs compiled by
the native backend never touch `/tmp`, including the `vmHostText` fixture. The
executor keeps the file only while it is built by `snl build`, whose host has
no string→bytes primitive. The path stays isolated in `vmStringStart` until
the executor itself is compiled natively (N3).

## Consequences

- Intentional divergences from `snl run-snbc` v0.3.0: string equality by
  content; arguments passed to the program; error messages on stdout with the
  `runtime error:` prefix, since the seed subset does not write to stderr.
- Opcodes the compiler does not use (double, globals, variants, defer/spawn)
  fail with `unsupported opcode`.
- The executor inherits the cost of the host C VM. Performance and runtime
  independence come from the native backend (ADR-0005).

## Reopen when

The executor is compiled by the native backend, the seed gains an index
assignment supported by the reference, or the native backend replaces the
host VM.
