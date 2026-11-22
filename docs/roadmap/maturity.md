# Compiler maturity assessment

This assessment describes the compiler in this repository as it stands on
2026-11-21. “Self-hosted” refers to the measured bootstrap cycle, not to full
language compatibility, release readiness, or an independent chain of trust.
See [`evidence.md`](evidence.md) for the commands and limits of each observed
gate.

## Current maturity

| Area | Current state | Work required for a mature compiler |
|---|---|---|
| Bootstrap | The restricted compiler source compiles itself to SnBC; its Snova executor reproduces that image. The native AArch64 Darwin compiler also reaches repeated assembly equality from the transitional `snl` root. `make bootstrap-reproducible` automates two builds from the same frozen source tree into separate clean output trees and writes source, toolchain and artifact hashes; this new gate still needs a complete run before it is evidence. | Record the run, preserve its outputs/logs, and establish an independent DDC root. The current gate compares SnBC and assembly, not signed Mach-O executables or different machines. |
| Frontend | Lexer, parser and lowering are split into source modules, but core data is held in parallel integer arrays and mutable `CompilerState`/`CompilerContext`; the compiler constructs an ordered joined source unit. | Introduce typed tokens, source spans, AST nodes, symbol identities and phase-owned results. Resolve imports and source order in the compiler rather than in a hardcoded source join. |
| Semantics | A small subset checks known local and field types and reports a few diagnostics; unknown expression types often pass through. | Build explicit name resolution and type checking with complete type compatibility, scopes, visibility, generics, traits, `impl` conformance and stable semantic diagnostics. |
| Object model | Class interfaces and `trait`/`impl Trait for Type` are parsed; `SNV4012` checks required method names, arity, parameter types and return types. SnBC interface/trait values dispatch through an O(log F) index; native values store concrete type ids and dispatch through O(1) tables. `make bootstrap-oop` and `make bootstrap-oop-native` cover dispatch and invalid contracts. | Add inheritance and inherited member resolution, generic traits, full type variance/coercion and compile-time generic dispatch. |
| Intermediate representation | Lowering writes SnBC directly from frontend state. The native backend decodes SnBC and translates opcodes. | Add a typed, validated, backend-independent IR with explicit control flow, calls, data layout and ownership effects; verify IR invariants before backend emission. |
| Backend architecture | Target metadata contracts now describe AArch64/Darwin and x86-64/Linux. The backend uses a target-kind selector for AArch64 symbols/sections, but the driver still fixes the target to `aarch64-apple-darwin`; the seed compares strings by identity and cannot lower virtual interface calls to SnBC. | Add content-based target parsing and a typed target context after seed support exists; then implement x86-64 instructions, SysV ABI, ELF/Linux entry/runtime, GNU toolchain selection and per-target qualification. |
| Generics and traits | Generic declarations/bounds and trait `impl` conformance are not implemented. Existing array types do not provide a general typed collection model. | Specify inference, bounds, coherence, monomorphization or dictionary dispatch, diagnostics and ABI rules; add accepted/rejected cases at seed, SnBC and native levels. |
| Runtime and safety | The native runtime has explicit ownership and detects strong cycles, but the frontend does not prove borrow/use-after-move safety and weak references are absent. | Add a language-level ownership/borrowing model, aliasing checks, weak references or a documented cycle policy, and runtime conformance across targets. |
| Compatibility and diagnostics | Existing evidence covers a limited subset; full `snovac` corpus differentials and precise lowering spans are absent. | Version the language subset, build a categorized differential corpus, stabilize diagnostic codes/spans, and publish unsupported behavior explicitly. |
| Delivery | The current build depends on installed `snl`, Apple assembler/linker and SDK. Multi-target qualification, clean-environment reproducibility and independent DDC are not shown. | Add pinned toolchain/bootstrap automation, CI gates per target, release packaging, artifact provenance and maintenance/versioning policy. |

## Complexity changes and limits

| Operation | Current complexity | Reason |
|---|---|---|
| Resolve an interface/trait method | `O(log F × L)` lookup after `O(F log F × L)` image-load indexing; `F` is function count and `L` is qualified-name length | A deterministic merge sort builds the index once, then binary search compares the requested concrete type and method against stored name bytes without allocating a joined string. |
| Native interface/trait call | `O(1)` runtime dispatch; `O(P × F × L)` table generation per call site, where `P` is string-pool size | The image pool offsets are indexed once, and each call site gets a type-indexed table of resolved function addresses. |
| Remove the final element from a guest array in the Snova VM | `O(n)` | `snl v0.3.0` cannot lower `array.pop()` in compiler source, so the current implementation copies the prefix. O(1) removal requires a predecessor capability or a different array representation. |
| Resolve frontend locals, fields and declarations | `O(n)` scans in several tables | The subset uses source-order parallel arrays and has no writable indexed table abstraction. Hash indexing can follow typed symbol tables and mutable collection support. |

## Architecture direction

Organize source by compiler phase and stable contracts rather than by growing
procedural state arrays:

1. **Source** owns file identities, byte buffers, spans and diagnostics.
2. **Syntax** owns tokens, AST declarations and expressions.
3. **Frontend** owns lexing and parsing behind typed input/output contracts.
4. **Semantics** owns module loading, symbol tables, type checking, trait
   solving and explicit implementation validation.
5. **IR** owns typed operations and verifiable invariants independent of any
   target.
6. **Backend** owns target resolution, ABI/layout, instruction selection,
   object writing and tool invocation behind narrow interfaces.
7. **Driver** owns projects, flags, diagnostics presentation and output
   artifacts.

Use classes/structs for state with a clear owner and lifecycle. Use interfaces
for services that must vary at runtime, such as the requested target's
instruction set or toolchain. Use traits and `impl` for compile-time behavior
reuse and conformance. Use generics for operations that preserve their input
and output types; do not erase types into `any` or use dynamic dispatch where
the concrete type is known. Keep each declaration in its own PascalCase source
file where this improves locality, and keep file names aligned with their
primary declaration.

## Ordered implementation gates

1. Complete interface and trait dispatch across the reference contract,
   SnBC executor and native backend; preserve concrete type identity.
2. Add inheritance and generic constraints to the language, seed, SnBC
   executor and diagnostics before using them in core compiler code.
3. Replace source joining and parallel frontend arrays with typed source,
   syntax and semantic contracts in small bootstrap-compatible slices.
4. Insert and verify typed IR before adding backend abstraction; keep the
   current Darwin backend as the first implementation behind those contracts.
5. Extend seed string equality and interface-call lowering so the driver can
   parse an explicit target triple and dispatch through target contracts.
   Verify the same fixture on SnBC and native output before enabling
   Linux/x86-64 emission.
6. Close the differential, clean-bootstrap, reproducibility and provenance
   gates before claiming general maturity or independent trust.

These gates extend [`stages.md`](stages.md), [`subset.md`](subset.md) and
[`ADR-0008`](../decisions/ADR-0008-multi-target-backend.md); they do not claim
that the proposed language features or targets already work.
