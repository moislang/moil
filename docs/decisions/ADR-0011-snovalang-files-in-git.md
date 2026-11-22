# ADR-0011 — Snovalang files in Git

- **Status:** Proposed; implemented in this repository
- **Date:** 2026-11-22

## Context

Git does not know `.snl` or `.snbc`: diffs of Snovalang sources show no
enclosing declaration in hunk headers, and SnBC images are diffed as text.
Repository settings such as `.gitattributes` apply only to the repository
that holds them; Git and GitHub have no organization-wide equivalent. The
support must not depend on third-party repositories, and for now no pull
request may be opened in other codebases.

Editor support (highlighting, colour, file icons, language features) is out
of scope for this repository: it belongs to the Snovalang language server
(LSP) and the editor extensions.

## Decision

1. `scripts/git/snovalang.gitattributes` holds the Git rules: `*.snl` as LF
   text with the `snovalang` diff driver, `*.snbc` binary and generated.
2. This repository's `.gitattributes` applies the same rules.
3. `make git-setup` installs the rules in the user's global attributes file
   (between `# >>> snovalang` and `# <<< snovalang`, replaced on re-run) and
   sets `diff.snovalang.xfuncname`, so hunk headers show the enclosing
   `func`/`method`/`class`/`struct`/`enum`/`interface`/`trait`/`impl` in
   every repository on that machine.
4. GitHub's Linguist does not know Snovalang; `.snl` is not mapped to
   another language, so language statistics stay correct.

## Consequences

- Organization-wide coverage is per developer: each person runs
  `make git-setup` once; no other repository changes.
- The diff driver needs that local setup; without it Git uses its default
  hunk headers. The LF and binary rules work from `.gitattributes` alone.

## Evidence

See the 2026-11-22 entry "Snovalang files in Git" in
[`evidence.md`](../roadmap/evidence.md).
