# ADR-0010 — Windows distribution through an MSI and winget

- **Status:** Proposed; packaging and release workflow implemented, not yet
  released; winget submission prepared but not enabled
- **Date:** 2026-11-22

## Context

Windows users need a command-line install for `moil`, the compiler built from
this repository. The earlier `moisc` tool is no longer the product to
distribute. The Windows build of `moil` is `build/bootstrap/moil.exe`:
an executable produced by `moil build` that bundles the compiler's SnBC image
with the seed's C VM (ADR-0005). There is no Windows native backend
(ADR-0008), so the installer ships that bundle, not native code.

## Decision

1. Package one MSI per release, built with WiX v5 from
   `packaging/windows/MoislangCompiler.wxs`. It installs `moil.exe` under
   `%ProgramFiles%\Moislang\Compiler\bin` (per machine), adds that folder to
   the machine `PATH`, and removes both on uninstall. The `UpgradeCode` is
   fixed for the life of the product.
2. Publish to winget as **`Moislang.Compiler`** (command `moil`), with
   `InstallerType: wix`. The manifests in `packaging/winget/` are templates;
   the release workflow fills version, URL, SHA-256 and ProductCode.
3. `.github/workflows/release-windows.yml` builds and tests the MSI on every
   change under `packaging/` and on `workflow_dispatch`. On a `vX.Y.Z[-pre]`
   tag it attaches the MSI to the GitHub release and, only when the
   `WINGET_TOKEN` secret exists, submits the manifests with `wingetcreate`.
4. Version mapping: winget uses the full SemVer version. MSI versions are
   numeric, so the MSI uses `X.Y.Z.N`, where `N` is the trailing number of a
   pre-release (0 otherwise). MSI ignores the fourth field for upgrades, so
   `MajorUpgrade` sets `AllowSameVersionUpgrades` and a newer preview, or the
   final release, replaces an install with the same `X.Y.Z`.
5. Release gate: the MSI is built only after the same tests as the Windows CI
   job pass, then installed, run (`Hello.snl` compiled and executed by the
   installed `moil`) and uninstalled on the runner. The executable may import
   only DLLs that ship with Windows.

## Consequences

- No release can be cut while the Windows tests fail.
- Only x86_64 is packaged; Windows ARM64 is out of scope until its CI passes
  in reasonable time.
- The first winget submission is a manual decision: create the
  `WINGET_TOKEN` secret (a GitHub token allowed to fork and open pull
  requests in `microsoft/winget-pkgs`), then push a release tag. Microsoft
  reviews each submission before it reaches users.
- The installed `moil` still carries the seed's C VM; this ADR does not change
  the bootstrap root (ADR-0009).

## Not verified

- The WiX build, install test and winget validation have not run yet; they
  run on a Windows runner (`windows-2025`).
- Whether `winget validate` is available on that runner; the workflow warns
  and skips validation when it is not.
