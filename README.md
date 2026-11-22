# snl

This repository develops a Snovalang compiler written in Snova. The compiler is the only public piece of the project; the source of the compiler and of its runtime stays in `.snl` and evolves through bootstrap stages.

## Start here

1. [Architecture overview](docs/architecture/overview.md)
2. [Incremental roadmap](docs/roadmap/stages.md)
3. [Architecture decisions](docs/decisions/README.md)
4. [Contribution rules](.claude/rules/architecture.md)
5. Skill [bootstrap-incremental](.claude/skills/bootstrap-incremental/SKILL.md)
6. [Development workflow](docs/workflows/development.md)
7. [Compiler bibliography](docs/research/compiler-literature.md)
8. Claude Code subagents in `.claude/agents/`
9. [Current compiler subset](docs/roadmap/subset.md)
10. [Compiler maturity assessment](docs/roadmap/maturity.md)

## Principles

- Each compiler compiles the next revision: the first seed does not have to understand the whole language.
- The compiler is written in Snovalang; assembly is limited to unavoidable system interfaces and to the initial seed where the host language is not enough.
- Capabilities of the installed `snl` are assumptions to measure with reproducible probes, never facts assumed by the plan.
- Reference compiler comparisons are recorded as evidence; this checkout remains the implementation source.
- C/C++ is not used to implement the compiler in this repository. The installed `snl` is only the transitional root of the initial bootstrap.
- Self-hosting, fixed point, reproducibility and DDC are distinct claims, each with its own evidence.

## Current bootstrap

`bootstrap/src/` holds the compiler and its I/O module in Snova; `bootstrap/runtime/` holds the native runtime in Snova, one type per responsibility; `bootstrap/library/` holds data structures and algorithms in Snova. `make bootstrap-build` produces `build/bootstrap/snova-bootstrap`. Run that binary with:

- `<input.snl> <output.snbc>` to compile;
- `<image.snbc>` to validate an image's structure;
- `<image.snbc> run [args...]` to execute an image on the SnBC executor written in Snova;
- `<input.snl> <output.s> native` to generate native assembly for the program and Snova runtime. `aarch64-apple-darwin` remains locally qualified; `aarch64-unknown-linux-gnu` now has an ELF entry point and Linux syscall runtime, tested by `make bootstrap-cli-linux-aarch64`. Linux x86_64 is tested for CLI/VM builds only; its native emitter is not implemented.

`make bootstrap-fixed-point` builds the multi-file project, compiles its own sources and compares two consecutive SnBC images. `SourceJoin.snl`, inside the compiler, assembles the compiler's own sources. The Snova executor runs the compiler's own image (`make bootstrap-vm-self`). `make bootstrap-native-self` builds the compiler as a native executable and checks two successive assembly fixed points on the qualified host. The first stage still comes from `snl build`; native assembly and linking use the host `as`/`ld`. The native backend is currently qualified only for `aarch64-apple-darwin`, and the compiler is not a drop-in replacement for `snovac`. See [ADR-0005](docs/decisions/ADR-0005-native-backend.md), the [evidence log](docs/roadmap/evidence.md), and the [subset matrix](docs/roadmap/subset.md).

`make bootstrap-reproducible` snapshots hashes for the frozen compiler source tree, runs the complete SnBC/native qualification gates in parallel into two separate empty output directories, compares all generated SnBC and assembly artifacts, and writes `build/bootstrap-reproducibility/provenance.json`. The directory preserves compared artifacts and separate build logs. This checks repeated builds on the current host with the installed `snl`; it does not compare signed Mach-O executables or prove independent DDC or reproducibility on another machine.

`make bootstrap-prerelease` runs the local qualification gates serially and assembles `build/prerelease/snova-0.1.0-preview.1-aarch64-apple-darwin.tar.gz` (override `SNOVA_RELEASE_VERSION` to choose another preview version). The bundle labels the supported subset, source revision, seed toolchain and known limitations. It is a local artifact, not a published release; this first preview does not claim independent DDC or compatibility with `snovac`.
