# Readings on bootstrap and compiler architecture

This bibliography gathers primary sources to guide the project. Follow the suggested order per topic; do not copy an architecture without checking that it fits the confirmed capabilities of `snl` and the requirements of Snovalang.

## Bootstrap and self-hosted compilers

1. **Huberdeau, Hamel, Monnier and Feeley, "The Design of a Self-Compiling C Transpiler Targeting POSIX Shell" (SLE 2024).** [Paper (PDF)](https://www-labs.iro.umontreal.ca/~feeley/papers/HuberdeauHamelMonnierFeeleySLE24.pdf), [DOI](https://doi.org/10.1145/3687997.3695639). Studies a limited seed, the boundary of the required subset, compilation of the transpiler itself and a reproducible toolchain. Local application: use the principle of a minimal seed and an explicit chain; do not assume the POSIX shell backend fits here.
2. **Wheeler, "Countering Trusting Trust through Diverse Double-Compiling" (ACSAC 2005).** [Paper (PDF)](https://profsandhu.com/cs5323_s17/wheeler-2005.pdf), [arXiv version](https://arxiv.org/abs/1004.5548). Explains DDC and its conditions. Local application: keep DDC separate from ordinary self-hosting and record the second trusted root and the required comparisons.
3. **Myreen, "A Minimalistic Verified Bootstrapped Compiler" (CPP 2021).** [Paper (PDF)](https://www.cse.chalmers.se/~myreen/cpp2021-bootstrap-myreen.pdf). Studies a formally verified bootstrapped compiler. Local application: a reference for separating trust in the bootstrap from verified correctness/semantics; formal verification is not in the first scope.
4. **GCC Internals — Makefile / bootstrap.** [Official documentation](https://gcc.gnu.org/onlinedocs/gccint/Makefile.html). Describes staged builds, output comparison and the "bubble" rebuild. Local application: inspiration for explicit gates and per-stage comparison, not for replicating GCC's complex build system.

## Compiler architecture and phases

5. **LLVM, "My First Language Frontend with LLVM" (Kaleidoscope).** [Official tutorial](https://llvm.org/docs/tutorial/MyFirstLanguageFrontend/). Builds lexer, parser/AST, IR/code generation, objects and debug info incrementally. Local application: a teaching sequence of vertical slices; the tutorial is not an architecture standard and warns that it simplifies engineering practices.
6. **Appel, "Modern Compiler Implementation".** [Author's overview](https://www.cs.princeton.edu/~appel/modern/), [topic description](https://www.cs.princeton.edu/~appel/modern/description.html), [Cambridge University Press](https://www.cambridge.org/core/books/modern-compiler-implementation-in-ml/C2A59C37468AA8AAD0ADDCE080E3CB5D). Covers frontend, IR, instruction selection, dataflow analysis, register allocation and runtime. Local application: a topic map for planning the compiler's evolution, avoiding optimizations before there is a measured need.
7. **Wirth, "Compiler Construction".** [Author's page](https://people.inf.ethz.ch/wirth/), which provides compiler construction material. Local application: a compact reference for grammar, parsing, data structures and code generation.

## Synthesis for this repository

- **Scale by capability:** a stage may only use features its predecessor compiles; the subset is a versioned interface, not an implicit expectation.
- **Keep phases testable:** lexer → parser/AST → semantics → IR → backend/runtime → driver, with phase-specific fixtures.
- **Compare stages carefully:** GCC's output comparison is a model for internal stability; DDC also requires a compilation with a diverse root under recorded assumptions.
- **Prioritize seed readability:** the seed is part of the chain of trust and must be small, deterministic and reviewable.
- **Record limits:** an equal artifact alone does not prove semantic correctness, assembler/linker safety, root independence or the absence of environmental differences.

## Rules for using the bibliography

When a skill or ADR applies an idea from these sources, name the source and the adaptation. Clearly mark any conclusion of your own as an inference. Prefer DOIs, authors/institutions and official documentation. Re-check URLs before depending on them in automation; reading links are references only and must not be downloaded/built without need.
