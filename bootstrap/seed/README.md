# SnBC seed for the first bootstrap stage

`compiler.mlbc` is the SnBC image of the Mois compiler in `bootstrap/src/`.
It is the first-stage seed proposed in
[ADR-0009](../../docs/decisions/ADR-0009-committed-snbc-seed.md): `make
bootstrap-seed-stage` runs it with `moil run-snbc`, and it compiles the
current sources without `moil check` or `moil build`.

This file is a generated artifact, not hand-written code. It is produced by
the compiler's own fixed point and must never be edited by hand.

## Provenance

| Field | Value |
|---|---|
| Source revision | Extension migration based on `59999bc`; refreshed from the current self-hosted compiler sources |
| Producing command | `make bootstrap-seed-refresh` (runs `make bootstrap-fixed-point`, copies `build/bootstrap/stage1.mlbc`) |
| Producing root | `snl v0.3.0` official darwin-aarch64 binary, used only to build the staged root project; the self-hosted compiler produced the seed |
| Host | `aarch64-apple-darwin` |
| Size | 190089 bytes |
| SHA-256 | `5b7f884c1a8ce8544bc549b45f3251cbab0bad8008eac12778d5742a71a1a650` (also in `compiler.mlbc.sha256`) |

The seed fixed point was checked on `aarch64-apple-darwin`; the root compiler
was still the older `.snl`-only v0.3.0 binary. Make stages temporary `.snl`
copies for that root while the checked-in source and refreshed seed use `.moi`.
The setup action pins that compatibility mode until a `.moi`-capable root is
published.

## Update flow

1. Run `make bootstrap-seed-fixed-point`. While it passes, the seed still
   compiles the current sources and does not need to change.
2. When it fails because the sources use a construct the seed cannot compile,
   run `make bootstrap-seed-refresh`, then `make bootstrap-seed-fixed-point`.
3. On Linux x86-64, also run the new seed on the Mois executor
   (`SNL_OUTPUT=build/bootstrap/vm-seed.mlbc build/bootstrap/moil
   bootstrap/seed/compiler.mlbc run`) and require the same SHA-256, because
   the `moil` v0.3.0 C VM miscompares some boolean values there (ADR-0009).
4. Update the provenance table above and add an entry to
   [`evidence.md`](../../docs/roadmap/evidence.md) with the new hash, host and
   `moil` version.
