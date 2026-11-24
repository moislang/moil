# ADR-0008 — Multi-target native backend rollout

- **Status:** Proposed
- **Date:** 2026-11-21

## Context

The Mois native backend is currently a single-target implementation for
`aarch64-apple-darwin`. Its instruction emitters use AArch64 registers and
instructions directly; its entry point, object format, system calls, and
assembler/linker commands are Darwin-specific. Selecting another triple
without changing all of those layers would create an invalid or unsafe claim
of support.

The previous `moisc` target matrix included qualified, pending-validation,
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

Model these dimensions with runtime-dispatched interfaces. The bootstrap now
has typed contracts and concrete AArch64/Darwin and x86-64/Linux descriptors.
The native backend routes a target-kind value through resolver metadata for
ISA, symbols, and sections. The current driver still fixes that value to the
only qualified target, AArch64/Darwin. The transitional seed compares strings
by identity and rejects virtual interface calls when lowering compiler
sources to SnBC (`MOISL0400`), so arbitrary triples and interface objects
cannot yet be used in the compiler execution path.

Keep `trait`/`impl` alongside interfaces. Interfaces define runtime
polymorphism for target-specific services. Traits and their implementations
provide reusable behavior and compile-time conformance for shared helpers.
Neither mechanism is a substitute for the other, and neither introduces an
untyped `any` escape hatch.

The backend-facing contracts are:

| Interface | Responsibility | Runtime implementation examples |
|---|---|---|
| `InstructionSet` | Instruction selection, registers, arithmetic, stack operations, branch encoding | AArch64, x86-64, RISC-V 64, ARM32, x86 |
| `CallingConvention` | Argument/return registers, preserved registers, stack alignment, variadic calls | AAPCS64, SysV AMD64, Win64 |
| `ExecutableFormat` | Sections, symbols, relocations, entry point and object writer/linker contract | Mach-O, ELF, PE/COFF |
| `OperatingSystemRuntime` | Entry state and host calls for I/O, memory mapping and process exit | Darwin/libSystem, Linux, Windows GNU, FreeBSD |
| `Toolchain` | Assembler/linker executable and target-specific arguments | Apple `as`/`ld`, GNU binutils, LLVM tools |

`NativeTargetResolver` exposes target-kind metadata. The emitter uses this
metadata for section and symbol generation. The `ProcessorArchitecture`,
`OperatingSystemRuntime`, `CallingConvention`, `ExecutableFormat`, and
`NativeToolchain` interfaces define the next dispatch boundary; the seed's
current SnBC lowering restriction means those virtual calls cannot yet be
used in the compiler execution path.

`ProcessorArchitecture` selection must follow the requested compilation
target, not the CPU that happens to run the compiler. The current compiler is
configured for `aarch64-apple-darwin`; it does not detect the host triple or
accept an explicit one yet. Resolving a user-supplied triple requires content
string equality in the seed, then the resolver can give the concrete target
kind to the backend. If the language later supports generic trait
constraints and monomorphization, a concrete compile-time parameter such as
`T: ProcessorArchitecture` can select an implementation statically. That is a
different mechanism from an interface value whose implementation is selected
at runtime, and it must not silently bind a cross compiler to its host CPU.

Target selection must be explicit. Unknown or unqualified targets fail with a
diagnostic that names the target and its current status. There is no fallback
to the host target. Assembler, linker, entry point, system calls, startup
state, and executable format are all part of a target backend. A shared ISA
backend may serve multiple operating systems only where the ABI and object
format contracts remain separate and tested.

## Current gap inventory

| Layer | Current implementation | Gap before another hosted target can run |
|---|---|---|
| Target selection | Current driver selects its configured `aarch64-apple-darwin` kind; resolver supplies metadata for AArch64/Darwin and planned x86-64/Linux | Implement content-based target parsing and host/configured default handling; wire providers into a typed target context after seed string equality and interface dispatch work |
| ISA and instruction emission | `NativeBackend` receives the resolved target kind, queries the resolver's ISA descriptor and admits only its AArch64 emitter; x86-64 is rejected before emission | Dispatch through `ProcessorArchitecture` providers and implement x86-64, RISC-V 64, ARM32, and x86 emitters; architecture-neutral image/ownership contracts |
| Calling convention | Resolver descriptors distinguish AAPCS64 and SysV AMD64; only AAPCS64 is enabled | Dispatch through `CallingConvention` providers and implement per-ABI argument, return, preserved-register, stack-alignment, and variadic-call emission |
| Process entry and executable format | `NativeBoundary` obtains section names and symbol spelling from the resolved format descriptor; only Mach-O is enabled. Darwin startup remains AArch64-specific | Dispatch through `ExecutableFormat`; implement ELF `_start`/startup, PE/COFF entry/imports, relocations and target-specific linker handling |
| Operating-system runtime | Resolver distinguishes Darwin from Linux; generated stubs still call Darwin `libSystem` | Dispatch through `OperatingSystemRuntime`; implement Linux, Windows, and FreeBSD I/O, memory mapping, process exit, error conventions, and startup-state adapters |
| Toolchain | Resolver identifies Apple tools and GNU binutils; `Makefile` still uses Apple assembler/linker commands | Dispatch through `NativeToolchain`; add per-target tool discovery/flags, cross-build prerequisites, and missing-tool diagnostics |
| Validation and qualification | Local Darwin/ARM64 fixtures; `.github/workflows/planning-docs.yml` validates documentation only | Hosted runners, native differential and ownership gates, self-compilation fixed point, and separate qualification status for every target |

## Language and dispatch prerequisite

The installed reference compiler accepts and interprets interface dispatch,
but its SnBC emitter rejects a call through an interface (`MOISL0400: cannot
lower call to SnBC`). The bootstrap compiles and runs interface and trait
dispatch through SnBC opcode 59. It retains concrete object type identity,
validates `class Type implements Contract` and explicit
`impl Contract for Type` conformance (method name, arity, parameter types and
return type), and builds a sorted method index for O(log F) VM lookup. The
native backend stores a concrete type pool id in each object and dispatches
through an O(1) type-indexed table. `make bootstrap-oop` and
`make bootstrap-oop-native` cover this slice locally on AArch64 Darwin.
Generic bounds, inheritance and qualification on other native targets remain
absent.

The `bootstrap/fixtures/InterfaceDispatch.snl` fixture verifies that the
bootstrap compiler, Mois VM and native executable select
`X64Architecture.code()` through an `Architecture` interface at runtime.
`TraitDispatch.snl` exercises equivalent dispatch through `impl`; negative
fixtures reject missing and mismatched contracts. The reference SnBC build
still rejects these calls, so these are bootstrap-specific gates.

Implementation order:

1. Preserve concrete type identity and function names in SnBC execution.
2. Expand contract validation with generic bounds and inheritance only after
   each feature has a specified seed subset and diagnostics.
3. Preserve and validate the SnBC virtual-call opcode and sorted resolver in
   the bootstrap fixed point.
4. Preserve type identity in native object layouts and add matching dynamic
   dispatch and ownership rules in `NativeBackend`. The Darwin/ARM64 slice is
   implemented; keep `bootstrap-oop-native` as a regression gate.
5. Begin Linux/x86-64 only after the same interface fixture passes in the seed,
   Mois executor, and native executable.

The previous `moisc` matrix is the source for target breadth, not evidence
that this bootstrap already supports those targets. Its Linux/x86-64 and
Windows/x86-64 entries were pending executable validation; the other listed
targets were unqualified, and bare-metal was explicitly blocked on selecting
a board/OS provider.

## Typed variadic functions

Add language-level varargs as a typed trailing rest parameter, conceptually
`func collect(prefix: string, values: int...)` called as
`collect("items", 1, 2, 3)`. The compiler checks every extra argument against
the declared element type and lowers the extras to one array value. The body
therefore sees a normal typed collection, and interface-dispatched methods use
the same representation. This is distinct from a platform C ABI variadic call:
only the native boundary applies ABI-specific register, stack, and promotion
rules. Untyped ellipses and implicit `any` packing are excluded.

The current parser and SnBC function metadata use fixed arity, so this is not
implemented yet. Add it after interface dispatch has a working typed call path:

1. Extend typed function declarations and call checking with one trailing
   homogeneous rest parameter; reject non-final or multiple rest parameters.
2. Lower call-site extras into a typed array and pass that array as one regular
   argument, keeping function arity and virtual dispatch stable.
3. Teach the seed, SnBC executor, and native backend the same semantics, with
   fixtures for zero, one, and multiple extra arguments and type mismatches.
4. Separately model external C varargs on `CallingConvention`; do not infer
   them from language-level rest parameters.

## Target matrix and rollout

| Stage | Target(s) | Initial status | Qualification gate |
|---|---|---|---|
| Current | `aarch64-apple-darwin` | Implemented and locally qualified | Existing native differential, ownership, smoke, and N3 fixed-point gates |
| T1 | `aarch64-unknown-linux-gnu` | ELF entry, AAPCS64 Linux syscalls, file flags, sections, symbols, relocations and GNU link path implemented; Docker differential covers 13 fixtures. Linux native self-host fixed point is not qualified | Keep ARM64 Docker CLI and native differential gates; resolve the Linux self-host mismatch before release qualification |
| T2 | `x86_64-unknown-linux-gnu` | Docker CLI/VM build tested; SysV AMD64 emitter, ELF entry/runtime and native link path are not implemented | Linux x86-64 runner; full native fixture differential, memory report, smoke, and self-compilation fixed point |
| T3 | `x86_64-pc-windows-gnu` | Not implemented in this backend; previously pending validation in `moisc` | Windows x86-64 runner; executable, ABI, I/O, ownership, and fixed-point gates |
| T4 | `x86_64-apple-darwin`, FreeBSD x86-64/AArch64 | Not implemented and unqualified | A runner and OS-specific ABI/link contract for each target; full native gates |
| T5 | `riscv64-unknown-linux-gnu` | Not implemented and unqualified | RISC-V 64 ISA and Linux ABI gates on a native runner or trusted emulator |
| T6 | ARM32, x86, remaining `*bsd` variants | Not implemented and unqualified | Per-target ABI, object format, runtime contract, and executable qualification |
| Separate | Bare-metal (`aarch64-none-elf`, `arm-none-eabi`, and others) | Not implemented; blocked | Board/OS provider selection and hardware integration evidence |

The first release target remains `aarch64-apple-darwin`. A target is listed as
supported only after it passes the executable qualification gate; assembly
generation or successful linking alone is insufficient.

## Acceptance criteria

- Target descriptors are typed and carry architecture, OS ABI, object format,
  assembler/linker configuration, and qualification state.
- Runtime interface dispatch selects distinct backend implementations for
  different target triples; `trait`/`impl` conformance remains statically
  checked for shared behavior.
- Typed rest parameters lower to a collection argument and behave identically
  through direct and interface-dispatched calls; external C varargs follow the
  selected target's calling-convention contract.
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

- AArch64 Darwin remains qualified while AArch64 Linux advances through its own
  ELF and runtime contract.
- Linux x86-64 remains the next full native backend because it was a pending
  qualification target in the prior compiler and has a practical CI runner.
- Windows x86-64 follows with its own Win64 ABI and PE/COFF link path.
- RISC-V, BSD, ARM32, x86, and bare-metal targets remain unqualified until
  their executable gates run; no version or marketing claim may imply coverage
  before then.
- Removing all external assembler/linker dependencies remains a separate
  milestone and is not required to qualify the first additional targets.
