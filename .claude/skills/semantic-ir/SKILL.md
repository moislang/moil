---
name: semantic-ir
description: Plan semantics, name/type resolution and an intermediate representation with explicit invariants.
---

# Semantics and intermediate representation

## Semantics

Separate symbol discovery, resolution, type inference/checking, control validation and lowering. Define the order and recovery after errors. Types and diagnostics must be typed, stable and testable. Do not imitate a behavior of the reference compiler without a fixture that demonstrates it.

## IR

Before adding an IR, record which problems it solves compared with a direct typed AST. If introduced, define:

- values, blocks, terminators, parameters and the return convention;
- supported types and value representation;
- invariants checkable before/after each lowering;
- ownership/lifetime and the origin of spans;
- deterministic serialization if the IR leaves the process.

## Flow

1. Write observable semantics and positive/negative examples.
2. Define the diagnostic and locate the responsible phase.
3. Choose the smallest representation that supports the current stage.
4. Implement invariant checks and divergence cases.
5. Make sure the predecessor compiles all new code.

Do not introduce full generics, closures, exceptions, optimizations or an SSA CFG only for symmetry with another compiler. Justify them by the next milestone.
