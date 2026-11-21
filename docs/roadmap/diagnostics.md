# Diagnostic correspondence

The seed keeps its own diagnostic namespace: `SNV1xxx` for lexical errors,
`SNV2xxx` for parse errors, `SNV3xxx` for lowering, `SNV4xxx` for semantic and
type errors and `SNV5xxx` for the future borrow checker
(SPEC-0002, PR #5: `SNV5001` corresponds to `SNOVA0240`, `SNV5002` to `SNOVA0251`).
`SNW0xxx` codes are warnings. Seed messages report a 1-based line and a byte
span in the single input buffer. `snl check` reports `SNOVAnnnn` codes with
line and column.

A differential against the reference compares two things: the
correspondence in this table, and the position (same line, and the seed span
starts at the reference column's byte). The literal codes are not compared.
Every row is backed by a fixture and a probe recorded in
[evidence.md](evidence.md).

| Seed code | Meaning | Reference code (`snl check` v0.3.0) | Seed position | Fixture |
|---|---|---|---|---|
| `SNV1001` | Lexical error | Lexer diagnostics (no single code) | Whole line | `invalidLex` |
| `SNV2001` | Parse error | Parser diagnostics, e.g. `SNOVA0106` | Failing token | `invalidParse` |
| `SNV3001` | Unsupported construct or invalid lowering | No counterpart (seed subset limit) | Line and function index | `invalidRuntimeArity`, `invalidStaticCall` |
| `SNV4001` | `let`/`var` annotation does not match initializer | `SNOVA0138` | Binding name | `invalidTypedLet` |
| `SNV4002` | Assignment type does not match local binding | `SNOVA0132` | Binding name | `invalidTypedAssignment` |
| `SNV4003` | Assignment type does not match field | `SNOVA0132` | Field name | `invalidFieldAssignment` |
| `SNV4004` | Non-exhaustive `match` on an enum | `SNOVA0205` | `match` keyword | `invalidMatchExpression`, `invalidMatchStatement` |
| `SNV4005` | Assignment to an immutable binding (`let`, parameter, `for` or `match` binding) | `SNOVA0047` | Binding name in the assignment | `invalidImmutableLet`, `invalidImmutableParam`, `invalidImmutableFor` |
| `SNW0001` | `==`/`!=` between known, different types (warning) | No warning; `SNOVA0133` rejects mismatched operators | Line | `warnMismatch` |

Known divergences, all recorded in [evidence.md](evidence.md):

- `SNV4004`: `snl check` v0.3.0 compares qualified pattern names
  (`Color.Red`) with bare member names. Because of that it also rejects
  complete qualified matches, and it accepts bare variant names, which it
  treats as bindings. The seed follows the documented rule.
