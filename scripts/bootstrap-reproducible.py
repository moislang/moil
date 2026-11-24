#!/usr/bin/env python3
"""Run two isolated bootstrap chains and record their provenance."""

from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOTS = (ROOT / "bootstrap",)
ARTIFACT_EXTENSIONS = (".mlbc", ".s")


def run(command: list[str], *, cwd: Path = ROOT, capture_output: bool = True) -> str:
    result = subprocess.run(
        command, cwd=cwd, check=True, text=True, capture_output=capture_output
    )
    return ((result.stdout or "") + (result.stderr or "")).strip()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_hashes(root: Path = ROOT) -> dict[str, str]:
    return {
        path.relative_to(root).as_posix(): sha256(path)
        for source_root in SOURCE_ROOTS
        for path in sorted((root / source_root.relative_to(ROOT)).rglob("*.moi"))
    }


def artifact_paths(root: Path) -> list[str]:
    return sorted(
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file() and path.suffix in ARTIFACT_EXTENSIONS
    )


def build_chain(build_dir: Path, moil: str) -> None:
    command = [
        "make",
        f"MOIL={moil}",
        f"BUILD_DIR={build_dir}",
        "bootstrap-smoke",
        "bootstrap-image-check",
        "bootstrap-vm",
        "bootstrap-diagnostics",
        "bootstrap-oop",
        "bootstrap-native",
        "bootstrap-oop-native",
        "bootstrap-library",
        "bootstrap-fixed-point",
        "bootstrap-vm-self",
        "bootstrap-native-self",
    ]
    temporary_dir = build_dir.parent / f"tmp-{build_dir.name}"
    temporary_dir.mkdir(parents=True)
    environment = os.environ.copy()
    environment["TMPDIR"] = str(temporary_dir)
    with (build_dir.parent / f"{build_dir.name}.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        if process.stdout is None:
            raise RuntimeError("could not capture bootstrap output")
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            log.write(line)
        status = process.wait()
        if status != 0:
            raise subprocess.CalledProcessError(status, command)


def main() -> int:
    if platform.system() != "Darwin" or platform.machine() not in ("arm64", "aarch64"):
        raise RuntimeError("clean native bootstrap is qualified only on Apple Silicon macOS")

    moil = os.environ.get("MOIL", "moil")
    moil_path = shutil.which(moil)
    if moil_path is None:
        raise RuntimeError(f"could not resolve reference compiler executable: {moil}")
    moil_version = run([moil, "--version"])
    source_files = source_hashes()
    source_files["Makefile"] = sha256(ROOT / "Makefile")
    source_files["scripts/bootstrap-reproducible.py"] = sha256(Path(__file__).resolve())
    revision = run(["git", "rev-parse", "HEAD"])
    working_tree_status = run(["git", "status", "--porcelain"])
    dirty = bool(working_tree_status)
    sdk_version = run(["xcrun", "--show-sdk-version"])
    assembler_path = Path(run(["xcrun", "-f", "as"])).resolve()
    linker_path = Path(run(["xcrun", "-f", "ld"])).resolve()
    output = (
        Path(sys.argv[1]).resolve()
        if len(sys.argv) > 1
        else ROOT / "build" / "bootstrap-reproducibility"
    )
    if len(sys.argv) > 2:
        raise RuntimeError("usage: bootstrap-reproducible.py [output-directory]")
    output.mkdir(parents=True, exist_ok=True)

    scratch_root = ROOT / "build"
    scratch_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="moil-repro-", dir=scratch_root
    ) as temporary:
        workspace = Path(temporary)
        first_build = workspace / "build-a"
        second_build = workspace / "build-b"
        with ThreadPoolExecutor(max_workers=2) as executor:
            builds = (
                executor.submit(build_chain, first_build, moil),
                executor.submit(build_chain, second_build, moil),
            )
            for build in as_completed(builds):
                build.result()

        first_artifacts = artifact_paths(first_build)
        second_artifacts = artifact_paths(second_build)
        if first_artifacts != second_artifacts:
            raise RuntimeError("bootstrap runs produced different artifact sets")
        if not first_artifacts:
            raise RuntimeError("bootstrap produced no reproducible SnBC or assembly artifacts")

        artifact_hashes: dict[str, str] = {}
        for relative_path in first_artifacts:
            left = first_build / relative_path
            right = second_build / relative_path
            if not left.is_file() or not right.is_file():
                raise RuntimeError(f"bootstrap did not produce {relative_path}")
            left_hash = sha256(left)
            right_hash = sha256(right)
            if left_hash != right_hash:
                raise RuntimeError(
                    f"non-reproducible artifact {relative_path}: {left_hash} != {right_hash}"
                )
            artifact_hashes[relative_path] = left_hash
            for run_name, artifact in (("run-a", left), ("run-b", right)):
                preserved = output / run_name / relative_path
                preserved.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(artifact, preserved)
        shutil.copy2(first_build.parent / "build-a.log", output / "run-a" / "build.log")
        shutil.copy2(second_build.parent / "build-b.log", output / "run-b" / "build.log")

        manifest = {
            "schema_version": 1,
            "claim": "repeated bootstrap from one frozen source tree into two clean output trees on one host",
            "repository_revision": revision,
            "working_tree_dirty": dirty,
            "working_tree_status": working_tree_status,
            "source_sha256": source_files,
            "toolchain": {
                "moil": moil_version,
                "moil_executable": str(Path(moil_path).resolve()),
                "moil_executable_sha256": sha256(Path(moil_path).resolve()),
                "host": platform.platform(),
                "machine": platform.machine(),
                "target": "aarch64-apple-darwin",
                "macos_version": run(["sw_vers", "-productVersion"]),
                "macos_sdk": sdk_version,
                "command_line_tools": run(["xcode-select", "-p"]),
                "assembler": {"path": str(assembler_path), "sha256": sha256(assembler_path)},
                "linker": {"path": str(linker_path), "sha256": sha256(linker_path)},
            },
            "artifact_sha256": artifact_hashes,
            "native_executables_compared": False,
            "independent_ddc": False,
        }

        manifest_path = output / "provenance.json"
        manifest_path.write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(f"reproducible bootstrap artifacts: {len(artifact_hashes)}")
        print(f"provenance: {manifest_path}")
        print("scope: same host/toolchain; this is not independent DDC")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"bootstrap reproducibility failed: {error}", file=sys.stderr)
        raise SystemExit(1)
