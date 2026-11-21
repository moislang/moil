---
name: backend-runtime
description: Design the backend, ABI and runtime while keeping the logic in Snovalang and limiting assembly to host boundaries.
---

# Backend and runtime

## Boundaries

Start with a single host target. Describe the target triple, object format, ABI, calling convention, alignment, stack frame, symbols, relocations, linker and required runtime. Assembly is allowed for ABI/OS calls that the language demonstrably lacks. Do not use C as a parallel path.

## Procedure

1. Choose a minimal vertical program and draw the flow IR → assembly/object → link → execution.
2. Specify the calling convention and register/stack ownership before emitting calls.
3. Implement basic operations, and compare output/performance only if that is a requirement.
4. Add external calls and runtime through small, typed, testable interfaces.
5. Check overflow, alignment, register preservation, symbols and exit/error behavior.
6. Record the differences between generating assembly, assembling, linking and running; do not call them generically "validated cross-compilation".
7. Only add another architecture after the host has stable vertical cases.
8. Memory is released deterministically through ownership (ADR-0006): prove zero live blocks at exit and constant peak memory in loops.

Each assembly routine requires a contract comment, platform/ABI, consumed/preserved registers and a matching test call.
