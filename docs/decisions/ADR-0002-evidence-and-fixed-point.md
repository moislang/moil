# ADR-0002 — Self-hosting and fixed-point evidence

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

"Compiles itself", binary equality, reproducible builds and Diverse Double-Compiling (DDC) are different properties. A bootstrap can work and still not produce stable bytes; repeating builds from the same root does not prove independence.

## Decision

Record separately: (1) a working bootstrap with a version chain; (2) artifact determinism; (3) reproducibility in clean builds; (4) a fixed point under an explicit comparison; and (5) DDC with a second, independent root. Document the toolchain, flags, target, allowed normalization and hash of each artifact.

## Consequences

- There will be no generic "self-hosted" claim without saying which gate was reached.
- Comparing assembly may be necessary when the executable format carries a UUID, timestamps or other environmental differences.
- Without a second independent root, DDC remains unproven, even if the other gates pass.

## Reopen when

The output format or the chain of trust changes, or observed comparisons show that another fixed-point definition is more appropriate.

## Initial evidence

Byte-for-byte equality of two SnBC images of the current seed was compared.
This records a fixed point restricted to the subset and to the root used; it
does not demonstrate independent reproducibility or DDC. See the evidence log.
