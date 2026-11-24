# ADR-0003 — Moislang as the main language; assembly at the boundaries

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

The goal is to demonstrate self-hosting in Moislang. At the same time, the first version may not expose primitives to start the process, call the assembler/linker or reach system calls and the ABI.

## Decision

Implement the compiler, runtime and tools in Moislang whenever the confirmed capabilities allow it. Allow assembly only at documented host boundaries: the minimal bootstrap and ABI/OS calls with no equivalent interface. Each boundary symbol needs a contract and an integration test. Do not allow C as an implementation shortcut.

## Consequences

- The inventory of available primitives comes before the seed design.
- The assembly set depends on each platform and must be minimized.
- The compiler, runtime and product-specific tools are written in Mois; C/C++ are not alternative implementation languages.
- The installed toolchain is a transitional root while the Mois compiler cannot produce and run its own artifact without the previous runtime.
- A need for C requires a separate decision proposal and a justification that Moislang/assembly cannot do it.

The SnBC path still uses the runtime supplied by `moil` to execute generated
SnBC. This is a bootstrap dependency, not a C implementation of the compiler
in this repository; removing it is an explicit migration gate. The native
path already follows this ADR: its runtime is Mois, and assembly is limited
to the stubs listed in ADR-0006.

## Reopen when

A native Moislang runtime interface makes an assembly boundary unnecessary, or evidence shows that an alternative is needed for the bootstrap chain.
