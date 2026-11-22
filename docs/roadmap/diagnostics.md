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
| `SNV4006` | Call argument count differs from the parameter count (function, static or instance method, `defer`/`pulsar` call), or a constructor receives more arguments than the class has fields | `SNOVA0131` | Called name | `invalidCallArity`, `invalidMethodArity`, `invalidConstructorArity` |
| `SNV4007` | Argument type does not match the parameter (function, static or instance method, positional constructor field, or `push` element type) | `SNOVA0132` | Opening `(` of the call | `invalidArgType`, `invalidMethodArgType`, `invalidConstructorType`, `invalidPushType` |
| `SNV4008` | Binary, comparison or logical operator applied to known incompatible operand types | `SNOVA0133` | Operator token | `invalidBinaryType`, `invalidCompareType`, `invalidStringOrder`, `invalidBoolOrder`, `warnMismatch` |
| `SNV4009` | Unary operand of a known incompatible type, or a known non-`int` index | `SNOVA0134` | Operator or opening `[` | `invalidUnaryNeg`, `invalidUnaryNot`, `invalidIndexType` |
| `SNW0001` | (unused) Was a warning for `==`/`!=` between known, different types; those cases are now `SNV4008` | `SNOVA0133` rejects them as errors | — | — |

In native mode the Snova runtime is appended to the user source. Line
numbers and the `invalidArgType` span stay relative to the user file
(`user_end` / `sourceLine`); the Linux gate compiles `hello.snl` to
`.s` with `native` and rechecks that fixture in native mode.

Known divergences, all recorded in [evidence.md](evidence.md):

- `SNV4004`: `snl check` v0.3.0 compares qualified pattern names
  (`Color.Red`) with bare member names. Because of that it also rejects
  complete qualified matches, and it accepts bare variant names, which it
  treats as bindings. The seed follows the documented rule.

## Gap inventory against `snl check` v0.3.0

Probe corpus: 41 single-function negative programs inside the seed subset,
each with a single error, checked with `snl check` (and `snl build` when check
passes) and with the seed. Recorded in [evidence.md](evidence.md) on
2026-11-21. "Seed now" is the seed's behavior on that date, including
`SNV4004`/`SNV4005` and statement lines for `SNV3001`.

| Case | Reference | Seed now | Gap | Priority |
|---|---|---|---|---|
| Call with the wrong argument count | `SNOVA0131` | `SNV4006` (it used to emit an invalid image) | Closed | — |
| Constructor with extra argument | `SNOVA0131` | `SNV4006` (it used to be accepted) | Closed | — |
| Argument of known wrong type (function, constructor, method, `push`) | `SNOVA0132` | `SNV4007` | Closed | — |
| `if`/`while` condition of known non-`bool` type | `SNOVA0135` | Accepted | Missing check | 2 |
| Unary `-` on `string`, `!` on `int` | `SNOVA0134` | `SNV4009` | Closed | — |
| Binary or ordering operator on known different types, or `<`/`>`/`<=`/`>=` on strings or bools | `SNOVA0133` | `SNV4008` (it used to warn with `SNW0001` only for `==`/`!=`) | Closed | — |
| Index of known non-`int` type | `SNOVA0134` | `SNV4009` | Closed | — |
| `return` type mismatch, value returned from `unit` function | `SNOVA0136` | Accepted | Function return types are not tracked | 3 |
| Initializer from a call of known return type | `SNOVA0138` | Accepted | Same: return types; also blocks `match f()` in `SNV4004` | 3 |
| Missing return on some path | `SNOVA0142` | Accepted | Needs control-flow analysis | 3 |
| Undefined name or function | `SNOVA0023` | `SNV3001` at the statement line | Generic code | 4 |
| Unknown field, method or enum member | `SNOVA0028` | `SNV3001` (field, method); enum member accepted | Generic code; enum member missing | 4 |
| Call of a non-function | `SNOVA0137` | `SNV3001` at the statement line | Generic code | 4 |
| `break`/`continue` outside a loop | `SNOVA0139`/`SNOVA0140` | `SNV3001` at the statement line | Generic code | 4 |
| Duplicate top-level function | `SNOVA0120` | Accepted (first wins) | Missing check | 4 |
| Private field read outside its class | `SNOVA0143` | Accepted | Missing check | 4 |
| Unknown type in an annotation | `SNOVA0027` | Accepted (unknown type) | Missing check | 4 |
| `var x` with no type and no initializer | `SNOVA0100` | Accepted | Missing check | 5 |
| Array literal with mixed element types | `SNOVA0149` | Accepted | Array element types not tracked | 5 |
| `for x: T` with the wrong element type | `SNOVA0150` | Accepted | Same | 5 |
| Empty `while true {}` (warning) | `SNOVA0216` | No warning | Warning not implemented | 5 |
| Move out of an array element (`let cell = cells[0]`) | `SNOVA0251` at the index expression | `SNV3001` on the next statement that uses `cell` (the field access on an unknown type), not on the move | Borrow checker: future `SNV5002` (SPEC-0002) | Borrow checker |
| Method call through a local alias of a field (`let local = counter; local.bump()`) | Accepted by `snl check`; `snl build` fails with `SNOVA0400` (cannot lower call to SnBC) | Accepted and lowered | Not a seed gap: `SNOVA0400` is a reference back-end limit. The ownership side belongs to the borrow checker (SPEC-0002) | Borrow checker |
| Instance method called through its type | Accepted by `snl check`; `snl build` fails with `SNOVA0400` | `SNV3001` at the statement line | Seed rejects earlier; a specific code is optional | 5 |
| Duplicate `let` in one scope | Accepted | Accepted | None | — |

Reference borrow codes found in `snovac` `src/sema/borrow.h` (tag `v0.3.0`),
for SPEC-0002: `SNOVA0240` use after move, `0241` use after drop, `0242`
exclusive borrow conflict, `0243` mutation while shared, `0244` send while
borrowed, `0245` null dereference, `0246` index out of bounds (static), `0247`
unsound `defer`, `0248` ownership-checker capacity exceeded (locals, active
borrows or task captures), `0249` reference rebound to different places across
branches, `0250` reference rebound across a loop iteration (loop-carried
borrows unsupported), `0251` move out of an array element or field.
`SNOVA0400` (`src/bc/emit_bc.h`) is `SNOVA_EMIT_UNSUPPORTED`: the reference
SnBC emitter cannot lower a construct.
