---
name: self-hosting-research
description: Research compiler bootstrapping and turn primary literature into decisions applicable to the Moislang compiler.
---

# Self-hosted compiler research

## Use when

Evaluating bootstrap, fixed point, chain of trust, DDC, reproducibility or an alternative seed architecture.

## Base sources

Read `docs/research/compiler-literature.md` before researching again. Start with the pnut/SLE 2024 papers and Wheeler's DDC, the GCC bootstrap documentation, and LLVM/Appel material for compiler phases.

## Procedure

1. State the engineering question and the comparison criteria.
2. Prioritize peer-reviewed papers, artifacts published by the authors, official documentation and original books/authors.
3. Separate results reported by the source from inferences for Moislang.
4. Extract validity conditions, limits and tool dependencies; do not summarize only the abstract.
5. Compare alternatives by seed cost, required features, host dependency, auditability and strength of evidence.
6. Recommend a small, reversible decision, with a probe or ADR to validate the uncertainties.
7. Update the bibliography and the affected ADR with direct links and the access date when a new source supports a decision.

## Checklist

- [ ] Primary source with a verifiable link?
- [ ] Evidence separated from inference?
- [ ] Were the assumptions that apply to the installed `moil` measured?
- [ ] Were self-hosting, reproducibility, fixed point and DDC kept apart?
- [ ] Does the recommendation keep Moislang as the implementation language?
