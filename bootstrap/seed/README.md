# SnBC seed for the first bootstrap stage

`compiler.snbc` is the SnBC image of the Snova compiler in `bootstrap/src/`.
It is the first-stage seed proposed in
[ADR-0009](../../docs/decisions/ADR-0009-committed-snbc-seed.md): `make
bootstrap-seed-stage` runs it with `snl run-snbc`, and it compiles the
current sources without `snl check` or `snl build`.

This file is a generated artifact, not hand-written code. It is produced by
the compiler's own fixed point and must never be edited by hand.

## Provenance

| Field | Value |
|---|---|
| Source revision | `2fba2df` (`master`) plus the ADR-0009 slice, which does not change `bootstrap/src/` |
| Producing command | `make bootstrap-seed-refresh` (runs `make bootstrap-fixed-point`, copies `build/bootstrap/stage1.snbc`) |
| Producing root | `snl v0.3.0`, official `snovac-linux-x86_64.tar.gz` release (archive SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`) |
| Host | `x86_64-unknown-linux-gnu` |
| Size | 142693 bytes |
| SHA-256 | `8cb80e985dbf2f5d087098fa02960e184d38ac540ffc39d936201404c5f730ad` (also in `compiler.snbc.sha256`) |

Equality with the image produced on `aarch64-apple-darwin` has not been
checked yet; see the evidence log.

## Update flow

1. Run `make bootstrap-seed-fixed-point`. While it passes, the seed still
   compiles the current sources and does not need to change.
2. When it fails because the sources use a construct the seed cannot compile,
   run `make bootstrap-seed-refresh`, then `make bootstrap-seed-fixed-point`.
3. Update the provenance table above and add an entry to
   [`evidence.md`](../../docs/roadmap/evidence.md) with the new hash, host and
   `snl` version.
