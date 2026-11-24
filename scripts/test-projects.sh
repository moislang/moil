#!/bin/sh
# Project resolution gate (SPEC-0003).
#
#   scripts/test-projects.sh portable <compiler> <build-dir>
#     Checks that give the same result on every host. Run with the SnBC
#     compiler bundle, which has no directory listing (HostShim.moi): type
#     imports, libraries, qualified entries and every pre-listing diagnostic,
#     plus SNV6010 for a package import.
#   scripts/test-projects.sh listing <compiler> <build-dir>
#     Checks that need the host listing (RUNTIME_CALL 9): `index`, package
#     imports and listing diagnostics. Run with the native compiler on a host
#     whose runtime lists folders (Linux AArch64).
set -u
mode=$1
compiler=$2
out=$3/projects
projects=bootstrap/fixtures/projects
invalid=$projects/invalid
mkdir -p "$out"
failures=0

# expect <name> <status> <expected first line or -> <command...>
expect() {
    name=$1
    status=$2
    line=$3
    shift 3
    "$@" > "$out/$name.txt" 2>&1
    actual=$?
    if [ "$actual" -ne "$status" ]; then
        echo "$name: exit $actual, expected $status"
        tr -d '\r' < "$out/$name.txt"
        failures=$((failures + 1))
        return
    fi
    if [ "$line" != "-" ] && ! tr -d '\r' < "$out/$name.txt" | grep -Fqx -- "$line"; then
        echo "$name: missing line: $line"
        tr -d '\r' < "$out/$name.txt"
        failures=$((failures + 1))
    fi
}

if [ "$mode" = portable ]; then
    expect app-run 42 "project app ok" "$compiler" run $projects/app/App.moi
    expect app-build 0 - "$compiler" build $projects/app/App.moi -o "$out/app.mlbc"
    expect app-image 42 "project app ok" "$compiler" "$out/app.mlbc" run
    here=$(pwd)
    case "$compiler" in /*|?:/*) absolute=$compiler ;; *) absolute=$here/$compiler ;; esac
    (cd $projects/app && "$absolute" run com.example.App) > "$out/app-qualified.txt" 2>&1
    status=$?
    if [ "$status" -ne 42 ]; then echo "app-qualified: exit $status, expected 42"; failures=$((failures + 1)); fi
    expect tool-no-listing 1 "error[SNV6010]: directory listing is not available on this host at line 4, span 57..77 in $projects/app/tools/Tool.moi" \
        "$compiler" run $projects/app/tools/Tool.moi
    expect root-flag-mismatch 1 "error[SNV6015]: --root-package does not match root.package in moislang.properties in $projects/app/moislang.properties" \
        "$compiler" run $projects/app/App.moi --root-package com.other
    expect root-flag-invalid 1 "error[SNV6014]: invalid package name" \
        "$compiler" run $projects/app/App.moi --root-package 9bad
    expect malformed-line 1 "error[SNV6001]: malformed property line at line 2, span 18..27 in $invalid/malformed-line/moislang.properties" \
        "$compiler" build $invalid/malformed-line/Main.moi -o "$out/x.mlbc"
    expect unknown-key 1 "error[SNV6002]: unknown property key at line 2, span 14..25 in $invalid/unknown-key/moislang.properties" \
        "$compiler" build $invalid/unknown-key/Main.moi -o "$out/x.mlbc"
    expect duplicate-key 1 "error[SNV6003]: duplicate property key at line 2, span 18..30 in $invalid/duplicate-key/moislang.properties" \
        "$compiler" build $invalid/duplicate-key/Main.moi -o "$out/x.mlbc"
    expect entry-not-found 1 "error[SNV6004]: entry not found in $invalid/none/Main.moi" \
        "$compiler" run $invalid/none/Main.moi
    expect no-package 1 "error[SNV6005]: entry file has no package declaration at line 1, span 0..0 in $invalid/no-package/Main.moi" \
        "$compiler" build $invalid/no-package/Main.moi -o "$out/x.mlbc"
    expect outside-root 1 "error[SNV6006]: entry package is not under the root package at line 1, span 8..17 in $invalid/outside-root/Main.moi" \
        "$compiler" build $invalid/outside-root/Main.moi -o "$out/x.mlbc"
    expect folder-mismatch 1 "error[SNV6007]: entry folders do not match its package segments at line 1, span 8..18 in $invalid/folder-mismatch/sub/Main.moi" \
        "$compiler" build $invalid/folder-mismatch/sub/Main.moi -o "$out/x.mlbc"
    expect package-mismatch 1 "error[SNV6008]: file package does not match its folder at line 1, span 8..18 in $invalid/package-mismatch/models/Thing.moi" \
        "$compiler" build $invalid/package-mismatch/Main.moi -o "$out/x.mlbc"
    expect unresolved-import 1 "error[SNV6009]: unresolved import at line 3, span 21..38 in $invalid/unresolved-import/Main.moi" \
        "$compiler" build $invalid/unresolved-import/Main.moi -o "$out/x.mlbc"
    expect missing-library 1 "error[SNV6011]: project folder has no moislang.properties with root.package in $invalid/missing-library/missing-library" \
        "$compiler" build $invalid/missing-library/Main.moi -o "$out/x.mlbc"
    expect library-collision 1 "error[SNV6012]: library root package is already the root of another project in $invalid/library-collision/self" \
        "$compiler" build $invalid/library-collision/Main.moi -o "$out/x.mlbc"
    expect main-outside-entry 1 "error[SNV6013]: main is declared outside the entry file at line 3, span 14..18 in $invalid/main-outside-entry/Helper.moi" \
        "$compiler" build $invalid/main-outside-entry/Main.moi -o "$out/x.mlbc"
    expect compile-error 1 "note: unit line 6 is line 6 of $invalid/compile-error/Broken.moi" \
        "$compiler" build $invalid/compile-error/Main.moi -o "$out/x.mlbc"
    expect usage 2 - "$compiler" build
elif [ "$mode" = listing ]; then
    expect app-index 0 - "$compiler" index $projects/app
    if ! tr -d '\r' < "$out/app-index.txt" | cmp -s - $projects/expected/app.index; then
        echo "app-index: output differs from $projects/expected/app.index"
        tr -d '\r' < "$out/app-index.txt"
        failures=$((failures + 1))
    fi
    expect tool-run 42 "hello from services" "$compiler" run $projects/app/tools/Tool.moi first second
    expect tool-build 0 - "$compiler" build $projects/app/tools/Tool.moi -o "$out/tool.mlbc"
    expect tool-image 41 "hello from services" "$compiler" "$out/tool.mlbc" run first
    expect index-package-mismatch 1 "error[SNV6008]: file package does not match its folder at line 1, span 8..18 in $invalid/package-mismatch/models/Thing.moi" \
        "$compiler" index $invalid/package-mismatch
    expect index-missing-source 1 "error[SNV6016]: source folder cannot be listed in $invalid/missing-source/nowhere" \
        "$compiler" index $invalid/missing-source
else
    echo "usage: scripts/test-projects.sh portable|listing <compiler> <build-dir>"
    exit 2
fi

if [ "$failures" -ne 0 ]; then
    echo "project gate ($mode): $failures failure(s)"
    exit 1
fi
echo "project gate ($mode) ok"
