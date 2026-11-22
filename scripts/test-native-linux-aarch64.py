#!/usr/bin/env python3
"""Differentially assemble and run the ARM64 ELF backend on Linux."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


FIXTURES = (
    "Hello",
    "NumericVm",
    "NumericFlow",
    "NativeCalls",
    "VmCalls",
    "VmComposite",
    "VmEquality",
    "StaticMethods",
    "VmArrayPop",
    "VmArrayPopString",
    "InterfaceDispatch",
    "TraitDispatch",
    "NativeMemory",
)


def run(command: list[str], *, expected_status: int | None = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if expected_status is not None and result.returncode != expected_status:
        raise RuntimeError(
            f"{command!r} exited {result.returncode}, expected {expected_status}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def emit(compiler: Path, build_dir: Path, target: str) -> None:
    """Compile each fixture to assembly and record the SnBC VM result.

    Runs on any host with the compiler; the VM result does not depend on it.
    """
    fixture_dir = Path("bootstrap/fixtures")
    build_dir.mkdir(parents=True, exist_ok=True)
    expected = {}
    for name in FIXTURES:
        source = fixture_dir / f"{name}.snl"
        image = build_dir / f"{name}-linux.snbc"
        assembly = build_dir / f"{name}-linux.s"
        run([str(compiler), str(source), str(image)])
        vm_result = run([str(compiler), str(image), "run", "alpha", "beta"], expected_status=None)
        run([str(compiler), str(source), str(assembly), "--target", target])
        expected[name] = {"exit": vm_result.returncode, "stdout": vm_result.stdout.replace("\r\n", "\n")}
        print(f"emitted {name} for {target} (VM exit {vm_result.returncode})")
    (build_dir / "expected.json").write_text(json.dumps(expected, indent=2, sort_keys=True) + "\n")


def run_native(build_dir: Path) -> None:
    """Assemble, link and run the emitted fixtures on a Linux AArch64 host.

    Needs only binutils; compares each executable with the recorded VM result.
    """
    expected = json.loads((build_dir / "expected.json").read_text())
    for name in FIXTURES:
        assembly = build_dir / f"{name}-linux.s"
        object_file = build_dir / f"{name}-linux.o"
        executable = build_dir / f"{name}-linux"
        run(["as", str(assembly), "-o", str(object_file)])
        run(["ld", "-static", "-e", "_start", str(object_file), "-o", str(executable)])
        native_result = run([str(executable), "alpha", "beta"], expected_status=None)
        vm = expected[name]
        if native_result.returncode != vm["exit"] or native_result.stdout != vm["stdout"]:
            raise RuntimeError(
                f"{name}: ELF/Linux differs from SnBC VM\n"
                f"VM exit/stdout: {vm['exit']}/{vm['stdout']!r}\n"
                f"ELF exit/stdout: {native_result.returncode}/{native_result.stdout!r}\n"
                f"ELF stderr: {native_result.stderr}"
            )
        print(f"Linux AArch64 differential passed: {name} (exit {native_result.returncode})")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--build-dir", required=True, type=Path)
    parser.add_argument("--target", default="aarch64-unknown-linux-gnu")
    parser.add_argument("--phase", choices=("all", "emit", "run"), default="all",
                        help="emit: compile fixtures and VM results (any host); run: assemble and run them (Linux AArch64)")
    args = parser.parse_args()
    if args.phase in ("all", "emit"):
        if args.compiler is None:
            parser.error("--compiler is required for the emit phase")
        emit(args.compiler, args.build_dir, args.target)
    if args.phase in ("all", "run"):
        run_native(args.build_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
