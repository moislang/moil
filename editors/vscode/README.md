# Snovalang for VS Code

Syntax highlighting, bracket and comment rules, and a file icon for
Snovalang sources (`.snl`). Everything lives in this repository: no
marketplace, npm package or third-party grammar.

- Language color: `#5B5BD6` (nova indigo), used by the `.snl` file icon.
- Grammar: `syntaxes/snovalang.tmLanguage.json` (TextMate; also usable by
  other editors that read TextMate grammars).

Install for your user (applies to every repository you open):

- From a release: `code --install-extension snovalang-<version>.vsix`
- From a clone of this repository: `make editor-vscode-install`

`make editor-vscode-vsix` builds the `.vsix` under `build/editors/` with
`zip` only. See [ADR-0011](https://github.com/snovalang/snl/blob/master/docs/decisions/ADR-0011-snovalang-file-support.md).
