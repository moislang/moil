---
name: conformance-determinism
description: Build differentials and evaluate bootstrap, determinism, fixed point, reproducibility and DDC with precise claims.
---

# Conformance and determinism

## Evidence matrix

Record as separate dimensions:

1. semantic conformance with reference cases;
2. build and execution of the successor compiler;
3. compilation of its own source by the newly generated stage;
4. equality of outputs between stages and the definition of the compared artifact;
5. repeated clean builds with fixed sources, flags and toolchain;
6. DDC with a diverse compiler/independent root and explicit assumptions.

## Procedure

1. Fix the corpus and the reference version.
2. Compare stdout, stderr, exit status, diagnostic/span and artifacts according to the kind of case.
3. Make diffs deterministic and reproducible; keep the cases that revealed differences.
4. For a fixed point, explain which bytes are compared and which environmental normalization is allowed.
5. For DDC, identify the diverse trusted origin concretely; repeating the compilation with the same compiler is not enough.
6. Record successes and failures by target/phase, without rounding percentages that have no denominator.

## Reporting

Say "compiles its own code" only after the reported stage does it. Say "reproducible" only after compared clean builds. Say "DDC proven" only with a second independent root and the method's conditions documented.
