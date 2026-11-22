# ADR-0011 — Snovalang file support for editors and Git

- **Status:** Proposed; implemented in this repository
- **Date:** 2026-11-22

## Context

`.snl` sources get no highlighting, colour or language detection anywhere.
GitHub detects languages with Linguist, which does not know Snovalang, and a
`.gitattributes` entry with an unknown language name is ignored. Repository
settings (`.gitattributes`, `.editorconfig`, `.vscode/`) apply only to the
repository that holds them; GitHub and Git have no organization-wide
equivalent. The support must not depend on third-party repositories, and
for now no pull request may be opened in other codebases.

## Decision

1. Keep all Snovalang file support in this repository, under `editors/`.
2. **Editor:** a VS Code extension in `editors/vscode/` with a TextMate
   grammar (keywords taken from the compiler's lexer), bracket/comment rules
   and a file icon in the language colour **`#5B5BD6`**. It is packaged as a
   `.vsix` with `zip` only (`make editor-vscode-vsix`, no `vsce` or npm),
   built on every pull request that touches `editors/`, and attached to each
   `vX.Y.Z` release. Installing it for a user covers every repository that
   user opens.
3. **Git:** `editors/git/snovalang.gitattributes` holds the rules (`*.snl`
   as LF text with the `snovalang` diff driver, `*.snbc` binary and
   generated). This repository's `.gitattributes` uses them, and
   `make git-setup` installs them in the user's global attributes file
   together with `diff.snovalang.xfuncname`, so hunk headers show the
   enclosing `func`/`method`/`class` in every repository on that machine.
4. **GitHub:** `.snl` is not mapped to another Linguist language, so
   statistics stay correct; it gets no highlighting on github.com until
   Snovalang is accepted by Linguist.
5. `.editorconfig` sets LF, a final newline and 4-space indentation for
   `.snl`.

## Consequences

- Organization-wide coverage is per developer: each person installs the
  extension and runs `make git-setup` once; no other repository changes.
- github.com shows `.snl` as plain text and leaves it out of the language
  bar.
- Later, without changing this decision: recommend the extension in other
  repositories' `.vscode/extensions.json`, publish to a registry, or submit
  the grammar and colour to Linguist.

## Evidence

See the 2026-11-22 entry "Snovalang file support" in
[`evidence.md`](../roadmap/evidence.md).
