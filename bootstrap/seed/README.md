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
| Source revision | `600ed17` (`master`, after snl#4, #7, #8 and #9; first refresh, see the evidence log) |
| Producing command | `make bootstrap-seed-refresh` (runs `make bootstrap-fixed-point`, copies `build/bootstrap/stage1.snbc`) |
| Producing root | `snl v0.3.0`, official `snovac-linux-x86_64.tar.gz` release (archive SHA-256 `f7d39f967407cdedc522b6bb1d21c199b188789dc27b00ba9e7100bc419ed8f8`) |
| Host | `x86_64-unknown-linux-gnu` |
| Size | 148729 bytes |
| SHA-256 | `cf64d0d31cb50b124af68b7f2dc78b9788f011a149528d36bef7ee4430397706` (also in `compiler.snbc.sha256`) |

Equality with the image produced on `aarch64-apple-darwin` has not been
checked yet; see the evidence log.

## Update flow

1. Run `make bootstrap-seed-fixed-point`. While it passes, the seed still
   compiles the current sources and does not need to change.
2. When it fails because the sources use a construct the seed cannot compile,
   run `make bootstrap-seed-refresh`, then `make bootstrap-seed-fixed-point`.
3. On Linux x86-64, also run the new seed on the Snova executor
   (`SNL_OUTPUT=build/bootstrap/vm-seed.snbc build/bootstrap/snova-bootstrap
   bootstrap/seed/compiler.snbc run`) and require the same SHA-256, because
   the `snl` v0.3.0 C VM miscompares some boolean values there (ADR-0009).
4. Update the provenance table above and add an entry to
   [`evidence.md`](../../docs/roadmap/evidence.md) with the new hash, host and
   `snl` version.
