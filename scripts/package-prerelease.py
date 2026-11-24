#!/usr/bin/env python3
"""Assemble a local, clearly scoped native compiler pre-release bundle."""

from __future__ import annotations

import hashlib
import json
import platform
import re
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main() -> int:
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        raise RuntimeError("usage: package-prerelease.py VERSION [output-directory]")
    version = sys.argv[1]
    if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+-preview\.[0-9]+", version) is None:
        raise RuntimeError("VERSION must match MAJOR.MINOR.PATCH-preview.N")
    if platform.system() != "Darwin" or platform.machine() not in ("arm64", "aarch64"):
        raise RuntimeError("the pre-release bundle is qualified only for Apple Silicon macOS")
    output = Path(sys.argv[2]).resolve() if len(sys.argv) == 3 else ROOT / "build" / "prerelease"
    compiler = ROOT / "build" / "bootstrap" / "compiler-native-stage2"
    provenance = ROOT / "build" / "bootstrap-reproducibility" / "provenance.json"
    if not compiler.is_file():
        raise RuntimeError("native fixed-point compiler is missing; run bootstrap-native-self first")
    if not provenance.is_file():
        raise RuntimeError("provenance manifest is missing; run bootstrap-reproducible first")

    bootstrap = json.loads(provenance.read_text(encoding="utf-8"))
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mois-prerelease-") as temporary:
        staging = Path(temporary) / f"mois-{version}-aarch64-apple-darwin"
        staging.mkdir()
        shutil.copy2(compiler, staging / "moil")
        shutil.copy2(provenance, staging / "provenance.json")
        shutil.copy2(ROOT / "bootstrap" / "README.md", staging / "bootstrap-README.md")
        shutil.copy2(ROOT / "LICENSE", staging / "LICENSE")
        shutil.copy2(ROOT / "NOTICE", staging / "NOTICE")
        shutil.copy2(ROOT / "bootstrap" / "LICENSE", staging / "bootstrap-LICENSE")
        shutil.copy2(ROOT / "bootstrap" / "NOTICE", staging / "bootstrap-NOTICE")
        shutil.copy2(ROOT / "docs" / "roadmap" / "subset.md", staging / "supported-subset.md")
        shutil.copy2(ROOT / "docs" / "roadmap" / "maturity.md", staging / "known-limitations.md")

        notes = {
            "name": "Moislang restricted compiler pre-release",
            "version": version,
            "target": "aarch64-apple-darwin",
            "compiler_sha256": digest(staging / "moil"),
            "source_revision": bootstrap["repository_revision"],
            "source_worktree_dirty": bootstrap["working_tree_dirty"],
            "bootstrap_root": bootstrap["toolchain"]["moil"],
            "independent_ddc": False,
            "scope": "experimental compiler subset; not a drop-in replacement for moisc",
            "native_executables_reproducibly_compared": False,
        }
        (staging / "release.json").write_text(
            json.dumps(notes, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        checksums = []
        for path in sorted(staging.iterdir()):
            checksums.append(f"{digest(path)}  {path.name}")
        (staging / "SHA256SUMS").write_text("\n".join(checksums) + "\n", encoding="utf-8")

        archive = output / f"mois-{version}-aarch64-apple-darwin.tar.gz"
        with archive.open("wb") as archive_stream:
            import gzip

            with gzip.GzipFile(fileobj=archive_stream, mode="wb", mtime=0) as gzip_stream:
                with tarfile.open(fileobj=gzip_stream, mode="w") as tar:
                    for path in sorted(staging.iterdir()):
                        info = tar.gettarinfo(str(path), arcname=f"mois-{version}-aarch64-apple-darwin/{path.name}")
                        info.mtime = 0
                        info.uid = 0
                        info.gid = 0
                        info.uname = ""
                        info.gname = ""
                        with path.open("rb") as source:
                            tar.addfile(info, source)
    print(f"pre-release bundle: {archive}")
    print(f"bundle sha256: {digest(archive)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, KeyError, json.JSONDecodeError) as error:
        print(f"pre-release packaging failed: {error}", file=sys.stderr)
        raise SystemExit(1)
