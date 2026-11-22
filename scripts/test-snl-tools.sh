#!/bin/sh
set -eu

repo_root=$(git rev-parse --show-toplevel)
snl_bin=${SNL:-snl}
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
    SNOVA_DOC_FORMAT=$format "$snl_bin" run "$repo_root/scripts/DocGenerate.snl" -- "$temporary_dir/Documented.snl" > "$temporary_dir/docs.$format"
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

SNOVA_CURRENT_VERSION=0.0.1 "$snl_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- v0.0.2 0.0.10 invalid > "$temporary_dir/patch.txt"
grep -F 'latest Git version tag: 0.0.10' "$temporary_dir/patch.txt" >/dev/null
grep -F 'next version: 0.0.11' "$temporary_dir/patch.txt" >/dev/null

if SNOVA_CURRENT_VERSION=0.0.1 SNOVA_RELEASE_BUMP=minor "$snl_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/minor-denied.txt" 2>&1; then
    echo "MINOR unexpectedly passed without compatibility evidence" >&2
    exit 1
fi
SNOVA_CURRENT_VERSION=0.0.1 SNOVA_RELEASE_BUMP=minor \
    SNOVA_MINOR_COMPATIBILITY_REVIEW=approved \
    SNOVA_MINOR_API_ADDITIONS="new compatible API" \
    SNOVA_RELEASE_NOTES="documented changes" \
    "$snl_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/minor-approved.txt"
grep -F 'next version: 0.1.0' "$temporary_dir/minor-approved.txt" >/dev/null

if SNOVA_CURRENT_VERSION=0.0.1 SNOVA_RELEASE_BUMP=major \
    SNOVA_BREAKING_CHANGE_REVIEW=approved SNOVA_RELEASE_NOTES="breaking" \
    "$snl_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/major-denied.txt" 2>&1; then
    echo "MAJOR unexpectedly passed outside a release" >&2
    exit 1
fi
SNOVA_CURRENT_VERSION=0.0.1 SNOVA_RELEASE_BUMP=major SNOVA_IS_RELEASE=1 \
    SNOVA_BREAKING_CHANGE_REVIEW=approved SNOVA_RELEASE_NOTES="1.0.0 release" \
    "$snl_bin" run "$repo_root/scripts/VersionFromGitTags.snl" -- 0.0.1 > "$temporary_dir/major-approved.txt"
grep -F 'next version: 1.0.0' "$temporary_dir/major-approved.txt" >/dev/null

printf 'SNL documentation and SemVer gates passed\n'
