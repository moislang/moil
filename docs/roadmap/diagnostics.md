# Diagnostic correspondence

The seed keeps its own diagnostic namespace: `SNV1xxx` for lexical errors,
`SNV2xxx` for parse errors, `SNV3xxx` for lowering, `SNV4xxx` for semantic and
type errors and `SNV5xxx` for the future borrow checker
(SPEC-0002, PR #5: `SNV5001` corresponds to `MOISL0240`, `SNV5002` to `MOISL0251`).
`SNW0xxx` codes are warnings. Seed messages report a 1-based line and a byte
span in the single input buffer. `moil check` reports `MOISLnnnn` codes with
line and column.

A differential against the reference compares two things: the
correspondence in this table, and the position (same line, and the seed span
starts at the reference column's byte). The literal codes are not compared.
Every row is backed by a fixture and a probe recorded in
[evidence.md](evidence.md).

| Seed code | Meaning | Reference code (`moil check` v0.3.0) | Seed position | Fixture |
|---|---|---|---|---|
| `SNV1001` | Lexical error | Lexer diagnostics (no single code) | Whole line | `invalidLex` |
| `SNV2001` | Parse error | Parser diagnostics, e.g. `MOISL0106` | Failing token | `invalidParse` |
| `SNV3001` | Unsupported construct or invalid lowering | No counterpart (seed subset limit) | Line and function index | `invalidRuntimeArity`, `invalidStaticCall` |
| `SNV4001` | `let`/`var` annotation does not match initializer | `MOISL0138` | Binding name | `invalidTypedLet` |
| `SNV4002` | Assignment type does not match local binding | `MOISL0132` | Binding name | `invalidTypedAssignment` |
| `SNV4003` | Assignment type does not match field | `MOISL0132` | Field name | `invalidFieldAssignment` |
| `SNV4004` | Non-exhaustive `match` on an enum | `MOISL0205` | `match` keyword | `invalidMatchExpression`, `invalidMatchStatement` |
| `SNV4005` | Assignment to an immutable binding (`let`, parameter, `for` or `match` binding) | `MOISL0047` | Binding name in the assignment | `invalidImmutableLet`, `invalidImmutableParam`, `invalidImmutableFor` |
| `SNV4006` | Call argument count differs from the parameter count (function, static or instance method, `defer`/`pulsar` call), or a constructor receives more arguments than the class has fields | `MOISL0131` | Called name | `invalidCallArity`, `invalidMethodArity`, `invalidConstructorArity` |
| `SNV4007` | Argument type does not match the parameter (function, static or instance method, positional constructor field, or `push` element type) | `MOISL0132` | Opening `(` of the call | `invalidArgType`, `invalidMethodArgType`, `invalidConstructorType`, `invalidPushType` |
| `SNV4008` | Binary, comparison or logical operator applied to known incompatible operand types | `MOISL0133` | Operator token | `invalidBinaryType`, `invalidCompareType`, `invalidStringOrder`, `invalidBoolOrder`, `warnMismatch` |
| `SNV4009` | Unary operand of a known incompatible type, or a known non-`int` index | `MOISL0134` | Operator or opening `[` | `invalidUnaryNeg`, `invalidUnaryNot`, `invalidIndexType` |
| `SNV4010` | `if`/`while` condition of a known non-`bool` type | `MOISL0135` | Start of the condition expression | `invalidIfCondition`, `invalidWhileCondition` |
| `SNV4011` | Returned type does not match the function's declared return type (including a value returned from `unit`, or a bare `return` from a non-`unit` function) | `MOISL0136` | `return` keyword (or the expression of a function shorthand) | `InvalidReturnType`, `InvalidReturnInUnit`, `InvalidBareReturn`, `InvalidMethodReturnType` |
| `SNV5001` | Use of a moved value | `MOISL0240` | Used binding | `InvalidUseAfterMove`, `InvalidConditionalMove` |
| `SNV5002` | Cannot move a value out of a field or array element | `MOISL0251` | `.` of a field, or `[` of an index | `InvalidFieldMove`, `InvalidElementMove` |
| `SNV4012` | Type does not satisfy its declared interface or trait contract (missing method, wrong arity or signature) | None: `moil check` v0.3.0 accepts the interface fixtures and rejects the trait fixtures earlier with `MOISL0102` | Contract name in the declaration | `InterfaceMissingMethod`, `InterfaceWrongSignature`, `TraitMissingMethod`, `TraitWrongArity` |
| `SNW0001` | (unused) Was a warning for `==`/`!=` between known, different types; those cases are now `SNV4008` | `MOISL0133` rejects them as errors | — | — |

In native mode the Mois runtime is appended to the user source. Line
numbers and the `invalidArgType` span stay relative to the user file
(`user_end` / `sourceLine`); the Linux gate compiles `Hello.moi` to
`.s` with `native` and rechecks that fixture in native mode.

Known divergences, all recorded in [evidence.md](evidence.md):

- `SNV4004`: `moil check` v0.3.0 compares qualified pattern names
  (`Color.Red`) with bare member names. Because of that it also rejects
  complete qualified matches, and it accepts bare variant names, which it
  treats as bindings. The seed follows the documented rule.

## Gap inventory against `moil check` v0.3.0

Probe corpus: 41 single-function negative programs inside the seed subset,
each with a single error, checked with `moil check` (and `moil build` when check
passes) and with the seed. Recorded in [evidence.md](evidence.md) on
2026-11-21. "Seed now" is the seed's behavior on that date, including
`SNV4004`/`SNV4005` and statement lines for `SNV3001`.

| Case | Reference | Seed now | Gap | Priority |
|---|---|---|---|---|
| Call with the wrong argument count | `MOISL0131` | `SNV4006` (it used to emit an invalid image) | Closed | — |
| Constructor with extra argument | `MOISL0131` | `SNV4006` (it used to be accepted) | Closed | — |
| Argument of known wrong type (function, constructor, method, `push`) | `MOISL0132` | `SNV4007` | Closed | — |
| `if`/`while` condition of known non-`bool` type | `MOISL0135` | `SNV4010` | Closed | — |
| Unary `-` on `string`, `!` on `int` | `MOISL0134` | `SNV4009` | Closed | — |
| Binary or ordering operator on known different types, or `<`/`>`/`<=`/`>=` on strings or bools | `MOISL0133` | `SNV4008` (it used to warn with `SNW0001` only for `==`/`!=`) | Closed | — |
| Index of known non-`int` type | `MOISL0134` | `SNV4009` | Closed | — |
| `return` type mismatch, value returned from `unit` function | `MOISL0136` | Accepted | Function return types are not tracked | 3 |
| Initializer from a call of known return type | `MOISL0138` | Accepted | Same: return types; also blocks `match f()` in `SNV4004` | 3 |
| Missing return on some path | `MOISL0142` | Accepted | Needs control-flow analysis | 3 |
| Undefined name or function | `MOISL0023` | `SNV3001` at the statement line | Generic code | 4 |
| Unknown field, method or enum member | `MOISL0028` | `SNV3001` (field, method); enum member accepted | Generic code; enum member missing | 4 |
| Call of a non-function | `MOISL0137` | `SNV3001` at the statement line | Generic code | 4 |
| `break`/`continue` outside a loop | `MOISL0139`/`MOISL0140` | `SNV3001` at the statement line | Generic code | 4 |
| Duplicate top-level function | `MOISL0120` | Accepted (first wins) | Missing check | 4 |
| Private field read outside its class | `MOISL0143` | Accepted | Missing check | 4 |
| Unknown type in an annotation | `MOISL0027` | Accepted (unknown type) | Missing check | 4 |
| `var x` with no type and no initializer | `MOISL0100` | Accepted | Missing check | 5 |
| Array literal with mixed element types | `MOISL0149` | Accepted | Array element types not tracked | 5 |
| `for x: T` with the wrong element type | `MOISL0150` | Accepted | Same | 5 |
| Empty `while true {}` (warning) | `MOISL0216` | No warning | Warning not implemented | 5 |
| Move out of an array element (`let cell = cells[0]`) | `MOISL0251` at the index expression | `SNV3001` on the next statement that uses `cell` (the field access on an unknown type), not on the move | Borrow checker: future `SNV5002` (SPEC-0002) | Borrow checker |
| Method call through a local alias of a field (`let local = counter; local.bump()`) | Accepted by `moil check`; `moil build` fails with `MOISL0400` (cannot lower call to SnBC) | Accepted and lowered | Not a seed gap: `MOISL0400` is a reference back-end limit. The ownership side belongs to the borrow checker (SPEC-0002) | Borrow checker |
| Instance method called through its type | Accepted by `moil check`; `moil build` fails with `MOISL0400` | `SNV3001` at the statement line | Seed rejects earlier; a specific code is optional | 5 |
| Duplicate `let` in one scope | Accepted | Accepted | None | — |

Reference borrow codes found in `moisc` `src/sema/borrow.h` (tag `v0.3.0`),
for SPEC-0002: `MOISL0240` use after move, `0241` use after drop, `0242`
exclusive borrow conflict, `0243` mutation while shared, `0244` send while
borrowed, `0245` null dereference, `0246` index out of bounds (static), `0247`
unsound `defer`, `0248` ownership-checker capacity exceeded (locals, active
borrows or task captures), `0249` reference rebound to different places across
branches, `0250` reference rebound across a loop iteration (loop-carried
borrows unsupported), `0251` move out of an array element or field.
`MOISL0400` (`src/bc/emit_bc.h`) is `SNOVA_EMIT_UNSUPPORTED`: the reference
SnBC emitter cannot lower a construct.
