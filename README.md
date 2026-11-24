# Moil

This repository develops a Moislang compiler written in Mois. The compiler is the only public piece of the project; the source of the compiler and of its runtime stays in `.snl` and evolves through bootstrap stages.

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
10. [Feature specifications](docs/specs/README.md)

## Principles

- Each compiler compiles the next revision: the first seed does not have to understand the whole language.
- The compiler is written in Moislang; assembly is limited to unavoidable system interfaces and to the initial seed where the host language is not enough.
- Capabilities of the installed `moil` are assumptions to measure with reproducible probes, never facts assumed by the plan.
- Reference compiler comparisons are recorded as evidence; this checkout remains the implementation source.
- C/C++ is not used to implement the compiler in this repository. The installed `moil` is only the transitional root of the initial bootstrap.
- Self-hosting, fixed point, reproducibility and DDC are distinct claims, each with its own evidence.

## Current bootstrap

`bootstrap/src/` holds the compiler and its I/O module in Mois; `bootstrap/runtime/` holds the native runtime in Mois, one type per responsibility; `bootstrap/library/` holds data structures and algorithms in Mois. `make bootstrap-build` stages `bootstrap/src/` and the library modules already migrated to an instance API into `build/bootstrap/root-project/` and produces `build/bootstrap/moil` from it. Run that binary with:

- `<input.snl> <output.snbc>` to compile;
- `<image.snbc>` to validate an image's structure;
- `<image.snbc> run [args...]` to execute an image on the SnBC executor written in Mois;
- `<input.snl> <output.s> --target <triple>` (or the older `native [<triple>]`, also `native --target <triple>`) to generate native assembly for the program and Mois runtime. The triple selects the executable format: `aarch64-apple-darwin` emits Mach-O (the default when no triple is given) and `aarch64-unknown-linux-gnu` emits ELF with a Linux syscall runtime. `x86_64-unknown-linux-gnu` is recognized but its native emitter is not implemented, so it fails with a diagnostic; there is no Windows native format. A malformed command line exits with status 2 and the usage text.
- In `make`, `NATIVE_TARGET=<triple>` selects the native build: `make bootstrap-native-target NATIVE_TARGET=aarch64-unknown-linux-gnu` builds and runs the native fixtures and builds `moil` itself as a native executable for that target (`build/bootstrap/native-<triple>/moil`, checked by a stage 2 = stage 3 fixed point). It needs the target's `as`/`ld`, so run it on a matching host or through `make bootstrap-cli-linux-aarch64`, which emits on the host and assembles and runs in a Linux ARM64 container that has no `moil`. `make bootstrap-target-cli` checks every command-line form and format marker without assembling, so it runs on any host. In CI, `gh workflow run platform-cli.yml -f native_target=<triple|all|none>` chooses which native builds run.

On Windows, `moil` is packaged as an MSI and prepared for winget as `Moislang.Compiler` ([ADR-0010](docs/decisions/ADR-0010-windows-msi-and-winget.md), proposed). Once a release is published and accepted by winget, install it with `winget install Moislang.Compiler`; the MSI installs `moil.exe` in `%ProgramFiles%\Moislang\Compiler\bin` and adds it to `PATH`. `.github/workflows/release-windows.yml` builds, installs, runs and uninstalls the MSI on every packaging change; a `vX.Y.Z[-pre]` tag attaches it to the release and submits it to winget only when the `WINGET_TOKEN` secret is configured.

`make bootstrap-fixed-point` builds the multi-file project, compiles its own sources and compares two consecutive SnBC images. `SourceJoin.snl`, inside the compiler, assembles the compiler's own sources. The Mois executor runs the compiler's own image (`make bootstrap-vm-self`). `make bootstrap-native-self` builds the compiler as a native executable and checks two successive assembly fixed points on the qualified host. `make bootstrap-seed-fixed-point` runs the committed SnBC seed (`bootstrap/seed/compiler.snbc`) with `moil run-snbc` only, checks the fixed point of that chain and compares its first stage with the `moil build` path ([ADR-0009](docs/decisions/ADR-0009-committed-snbc-seed.md), proposed). The compiler CLI still comes from `moil build`, and the seed chain still runs on the `moil` C VM; native assembly and linking use the host `as`/`ld`. The native backend is currently qualified only for `aarch64-apple-darwin`, and the compiler is not a drop-in replacement for `moisc`. See [ADR-0005](docs/decisions/ADR-0005-native-backend.md), the [evidence log](docs/roadmap/evidence.md), and the [subset matrix](docs/roadmap/subset.md).
