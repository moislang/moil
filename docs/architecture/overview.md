# Architecture overview

## Goal

Build in this repository a compiler that compiles its own source code, keeping Snovalang as the implementation language. The reference compiler `../snovac` serves as an observable specification and oracle during the migration; this work must not modify it.

The compiler is the only public product. Its frontend, semantics, backend,
runtime and driver must be developed in Snova. The installed `snl` root is
temporary; C/C++ will not be a parallel implementation. The current code is in
importable `.snl` modules in the `bootstrap/src/` project, with small public
APIs, and the native runtime is in `bootstrap/runtime/`. `snl build` uses
these modules directly and produces an executable that bundles SnBC with the
`snl` C VM (not machine code of the program; see ADR-0005). The native backend
emits aarch64 machine code for the program plus the Snova runtime, linked only
against `libSystem` (ADR-0006). To compile itself, the seed still assembles
one source unit internally; resolving imports between arbitrary files is the
next architecture gate. The remaining gaps are in `docs/roadmap/subset.md`.

## Strategy: bootstrap through cumulative subsets

The seed and the compiler share a common subset. Each milestone extends the language that the previous compiler can accept. The compiler source only uses features already supported by the immediately previous compiler. This avoids an arbitrary boundary between a simple dialect K and a language S that the seed cannot compile.

```mermaid
flowchart LR
  H[installed and probed snl] --> K[Minimal seed in subset K]
  K --> C1[Compiler 1: subset 0]
  C1 --> C2[Compiler 2: subset 1]
  C2 --> C3[Compiler N: agreed complete subset]
  C3 --> SH[Compiles its own code]
  SH --> FP[Successive builds compared]
  FP --> DDC[Independent DDC, once an independent root exists]
```

```mermaid
flowchart TB
  SRC[Snovalang sources] --> L[Lexer]
  L --> P[Parser and AST]
  P --> S[Resolution and semantics]
  S --> IR[Explicit, validated IR]
  IR --> B[Target backend]
  B --> OBJ[Assembly/object/executable]
  R[Snovalang runtime] --> B
  A[OS boundary assembly] --> R
  D[Driver and projects] --> L
```

The Mermaid versions used in these diagrams must be supported by the GitHub renderer. The `.mmd` files in `docs/diagrams/` are the editable sources.

## Proposed components

- **Seed**: small, auditable, deterministic and limited to the subset confirmed by probes. It generates the next compiler; it does not try to implement the whole language.
- **Frontend**: lexer, parser, AST, names, types and diagnostics compatible with the documented reference behavior.
- **IR**: a backend-independent representation with explicit invariants and validation.
- **Backend**: initially a single host target. Other targets come only after the first vertical path is stable.
- **Runtime**: implemented in Snovalang whenever possible; assembly only for the ABI, system calls and primitives with no equivalent language API. The native runtime follows this rule: memory, strings, arrays, objects, printing and files are Snova, and assembly is limited to stubs for memory primitives and six libSystem calls (ADR-0006).
- **Driver**: minimal CLI first; compatibility with existing commands and flags grows in stages.
- **Conformance harness**: compares the new compiler's results with the reference `snl`/`snovac` without modifying the reference checkout.

The final physical layout stays deliberately open until the discovery milestone. A suggested structure is `seed/`, `compiler/`, `runtime/`, `docs/` and `scripts/`, but the names must not force a premature split or duplicate modules.

## Boundaries and contracts

1. Each phase receives explicit data and returns results/diagnostics; errors do not stop the process through exceptions before validated support exists.
2. Serialization and ordering of symbols, strings, diagnostics and artifacts are deterministic.
3. No language feature is added without a probe, a subset specification and positive/negative cases.
4. The seed, compiler, runtime and validation tools have documented responsibility boundaries.
5. Assembly does not become a general implementation language: every assembly function has an ABI, platform, ownership and call-test contract.

## Definition of self-hosted

Self-hosted means that a compiler version, built by an identified bootstrap, compiles the sources of the next compiler. A fixed point requires successive builds to produce comparable artifacts that are equal under a defined policy. Reproducibility requires repeated clean builds with recorded inputs and toolchains. DDC requires an independent root of trust and is reported separately; two builds produced by the same root are not DDC.

See [ADR-0001](../decisions/ADR-0001-incremental-subsets.md), [ADR-0002](../decisions/ADR-0002-evidence-and-fixed-point.md) and the [roadmap](../roadmap/stages.md).
