# ADR-0008 — Multi-target native backend rollout

- **Status:** Proposed
- **Date:** 2026-11-21

## Context

The Snova native backend is currently a single-target implementation for
`aarch64-apple-darwin`. Its instruction emitters use AArch64 registers and
instructions directly; its entry point, object format, system calls, and
assembler/linker commands are Darwin-specific. Selecting another triple
without changing all of those layers would create an invalid or unsafe claim
of support.

The previous `snovac` target matrix included qualified, pending-validation,
unqualified, and blocked targets. This project will recover that breadth in
stages while keeping each target's implementation status distinct from its
qualification status.

## Decision

Separate native compilation into explicit target dimensions:

1. **Instruction set:** AArch64, x86-64, RISC-V 64, ARM32, and x86.
2. **Object format and linker:** Mach-O, ELF, PE/COFF, or a documented
   bare-metal format.
3. **Operating-system ABI:** Darwin, Linux, Windows GNU, FreeBSD, or a
   selected bare-metal platform provider.

Target selection must be explicit. Unknown or unqualified targets fail with a
diagnostic that names the target and its current status. There is no fallback
to the host target. Assembler, linker, entry point, system calls, startup
state, and executable format are all part of a target backend. A shared ISA
backend may serve multiple operating systems only where the ABI and object
format contracts remain separate and tested.

## Target matrix and rollout

| Stage | Target(s) | Initial status | Qualification gate |
|---|---|---|---|
| Current | `aarch64-apple-darwin` | Implemented and locally qualified | Existing native differential, ownership, smoke, and N3 fixed-point gates |
| T1 | `x86_64-unknown-linux-gnu` | Not implemented in this backend; previously pending validation in `snovac` | Linux x86-64 runner; full native fixture differential, memory report, smoke, and self-compilation fixed point |
| T2 | `x86_64-pc-windows-gnu` | Not implemented in this backend; previously pending validation in `snovac` | Windows x86-64 runner; executable, ABI, I/O, ownership, and fixed-point gates |
| T3 | `aarch64-unknown-linux-gnu`, `x86_64-apple-darwin`, FreeBSD x86-64/AArch64 | Not implemented and unqualified | A runner and OS-specific ABI/link contract for each target; full native gates |
| T4 | `riscv64-unknown-linux-gnu` | Not implemented and unqualified | RISC-V 64 ISA and Linux ABI gates on a native runner or trusted emulator |
| T5 | ARM32, x86, remaining `*bsd` variants | Not implemented and unqualified | Per-target ABI, object format, runtime contract, and executable qualification |
| Separate | Bare-metal (`aarch64-none-elf`, `arm-none-eabi`, and others) | Not implemented; blocked | Board/OS provider selection and hardware integration evidence |

The first release target remains `aarch64-apple-darwin`. A target is listed as
supported only after it passes the executable qualification gate; assembly
generation or successful linking alone is insufficient.

## Acceptance criteria

- Target descriptors are typed and carry architecture, OS ABI, object format,
  assembler/linker configuration, and qualification state.
- The CLI rejects unsupported or unqualified targets before emitting an
  artifact that could be mistaken for a runnable executable.
- Each qualified target runs the shared SnBC/native fixture corpus, checks
  diagnostics and exit status, reports zero live blocks for successful
  ownership fixtures, and passes its self-compilation fixed point.
- CI runs the target's executable gates on a native runner or a documented,
  trusted emulator. Results are reported per target, never combined into one
  green status.
- Release metadata names supported triples and host toolchain prerequisites.
  Source builds, cross-builds, and executable runs are reported separately.

## Consequences

- The AArch64 Darwin implementation remains the reference while target-specific
  code moves behind explicit architecture, ABI, and object-format boundaries.
- Linux x86-64 is the first new backend because it was a pending qualification
  target in the prior compiler and has a practical CI runner.
- Windows x86-64 follows with its own Win64 ABI and PE/COFF link path.
- RISC-V, BSD, ARM32, x86, and bare-metal targets remain unqualified until
  their executable gates run; no version or marketing claim may imply coverage
  before then.
- Removing all external assembler/linker dependencies remains a separate
  milestone and is not required to qualify the first additional targets.
