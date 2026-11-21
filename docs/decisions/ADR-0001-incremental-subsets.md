# ADR-0001 — Bootstrap through cumulative subsets

- **Status:** Accepted; initial bootstrap in progress
- **Date:** 2026-11-21

## Context

A limited seed that tries to generate a compiler written in a much wider subset creates a capability gap: the seed must implement a complex compiler before it can compile its own implementation language. The real capability of `snl build` also depends on the installed version and has to be measured.

## Decision

Use a sequence of cumulative subsets. The seed compiles the smallest measured subset; each stage generates the next one and only uses features its predecessor supports. Do not adopt a separate language S by assumption.

## Consequences

- The first seed stays small and easy to audit.
- Features enter in verifiable steps, and the initial compiler stays useful during the expansion.
- The sequence of subsets, probes and fixtures becomes part of the documentation and CI.
- More stages may be needed; optimizations and advanced features come after the vertical path.

## Reopen when

A concrete alternative (for example a compatible existing compiler or a trusted external generator) provably shortens the chain without violating the requirement to implement in Snovalang.

## Initial evidence

The seed in `bootstrap/src/` is a Snova subset and compiled its own source to
SnBC; the next image matched byte for byte. The matrix and the limitations are
in [`docs/roadmap/subset.md`](../roadmap/subset.md) and
[`docs/roadmap/evidence.md`](../roadmap/evidence.md).
