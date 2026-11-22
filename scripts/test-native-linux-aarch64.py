#!/usr/bin/env python3
"""Differentially assemble and run the ARM64 ELF backend on Linux."""

from __future__ import annotations

import argparse
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", required=True, type=Path)
    parser.add_argument("--build-dir", required=True, type=Path)
    parser.add_argument("--target", default="aarch64-unknown-linux-gnu")
    args = parser.parse_args()
    fixture_dir = Path("bootstrap/fixtures")
    args.build_dir.mkdir(parents=True, exist_ok=True)

    for name in FIXTURES:
        source = fixture_dir / f"{name}.snl"
        image = args.build_dir / f"{name}-linux.snbc"
        assembly = args.build_dir / f"{name}-linux.s"
        object_file = args.build_dir / f"{name}-linux.o"
        executable = args.build_dir / f"{name}-linux"

        run([str(args.compiler), str(source), str(image)])
        vm_result = run([str(args.compiler), str(image), "run", "alpha", "beta"], expected_status=None)
        run([str(args.compiler), str(source), str(assembly), "--target", args.target])
        run(["as", str(assembly), "-o", str(object_file)])
        run(["ld", "-static", "-e", "_start", str(object_file), "-o", str(executable)])
        native_result = run([str(executable), "alpha", "beta"], expected_status=None)

        if native_result.returncode != vm_result.returncode or native_result.stdout != vm_result.stdout:
            raise RuntimeError(
                f"{name}: ELF/Linux differs from SnBC VM\n"
                f"VM exit/stdout: {vm_result.returncode}/{vm_result.stdout!r}\n"
                f"ELF exit/stdout: {native_result.returncode}/{native_result.stdout!r}\n"
                f"ELF stderr: {native_result.stderr}"
            )
        print(f"Linux AArch64 differential passed: {name} (exit {native_result.returncode})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
