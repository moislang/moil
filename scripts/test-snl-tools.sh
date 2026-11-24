#!/bin/sh
set -eu

repo_root=$(git rev-parse --show-toplevel)
moil_bin=${MOIL:-moil}
temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT HUP INT TERM

cat > "$temporary_dir/Documented.snl" <<'SNL'
package example.api

/// Returns a quoted "result".
@Documented()
public func convert(value: string): int {
    return value.length()
}

public func internalHelper(): int {
    return 1
}
SNL

for format in yaml yml csv json; do
    MOIS_DOC_FORMAT=$format "$moil_bin" run "$repo_root/scripts/DocGenerate.snl" -- "$temporary_dir/Documented.snl" > "$temporary_dir/docs.$format"
done
cmp "$temporary_dir/docs.yaml" "$temporary_dir/docs.yml"
grep -F '"@Documented()"' "$temporary_dir/docs.yaml" >/dev/null
python3 - "$temporary_dir/docs.json" "$temporary_dir/docs.csv" <<'PY'
import csv
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    records = json.load(stream)
assert len(records) == 1 and records[0]["name"] == "convert", records
assert records[0]["annotation"] == "@Documented()"
assert records[0]["description"] == 'Returns a quoted "result".'
with open(sys.argv[2], newline="", encoding="utf-8") as stream:
    rows = list(csv.DictReader(stream))
assert len(rows) == 1 and rows[0]["name"] == "convert", rows
assert rows[0]["annotation"] == "@Documented()"
PY

MOIS_CURRENT_VERSION=0.0.1 "$moil_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- v0.0.2 0.0.10 invalid > "$temporary_dir/patch.txt"
grep -F 'latest Git version tag: 0.0.10' "$temporary_dir/patch.txt" >/dev/null
grep -F 'next version: 0.0.11' "$temporary_dir/patch.txt" >/dev/null

if MOIS_CURRENT_VERSION=0.0.1 MOIS_RELEASE_BUMP=minor "$moil_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/minor-denied.txt" 2>&1; then
    echo "MINOR unexpectedly passed without compatibility evidence" >&2
    exit 1
fi
MOIS_CURRENT_VERSION=0.0.1 MOIS_RELEASE_BUMP=minor \
    MOIS_MINOR_COMPATIBILITY_REVIEW=approved \
    MOIS_MINOR_API_ADDITIONS="new compatible API" \
    MOIS_RELEASE_NOTES="documented changes" \
    "$moil_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/minor-approved.txt"
grep -F 'next version: 0.1.0' "$temporary_dir/minor-approved.txt" >/dev/null

if MOIS_CURRENT_VERSION=0.0.1 MOIS_RELEASE_BUMP=major \
    MOIS_BREAKING_CHANGE_REVIEW=approved MOIS_RELEASE_NOTES="breaking" \
    "$moil_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/major-denied.txt" 2>&1; then
    echo "MAJOR unexpectedly passed outside a release" >&2
    exit 1
fi
MOIS_CURRENT_VERSION=0.0.1 MOIS_RELEASE_BUMP=major MOIS_IS_RELEASE=1 \
    MOIS_BREAKING_CHANGE_REVIEW=approved MOIS_RELEASE_NOTES="1.0.0 release" \
    "$moil_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/major-approved.txt"
grep -F 'next version: 1.0.0' "$temporary_dir/major-approved.txt" >/dev/null

printf 'Mois documentation and SemVer gates passed\n'
