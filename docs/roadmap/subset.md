# Compiler subset

This matrix separates implemented capability from compatibility with
`snovac`. A row only advances after compiler Snova source uses the feature and
a previous stage can compile it.

| Area | Current seed | Next gate |
|---|---|---|
| Compiler sources | camelCase `.snl` modules; project build; internal assembly of its own sources | Resolve imports and compile general projects directly in the Snova compiler |
| Frontend | Subset lexer/parser with stable `SNV1001` lexical and `SNV2001` parse diagnostics carrying byte spans; `SNV3001` identifies lowering failures by line and function index; classes with fields, instance methods, positional constructors, `static` methods and skipped `@Annotation`s (ADR-0007) | Precise lowering spans, phase-specific messages, semantic diagnostics and a versioned differential against the reference |
| Semantics | Local resolution needed by the subset; static types of literals, locals, parameters and fields; `let`/`var` initializer annotations, local assignments and field assignments checked when both types are known (`SNV4001`–`SNV4003` on mismatch); `match` on a subject whose static type is a known enum must have a `_`/binding arm or cover every variant (`SNV4004`, the rule of snovac `sn_check_match_exhaustiveness`/`SNOVA0205`; function return types are not yet known, so a call subject is not checked); codes map to `snl check` codes in [diagnostics.md](diagnostics.md)); warning `SNW0001` for `==`/`!=` between known, different types (does not stop compilation) | Complete type compatibility and diagnostics by milestones; full spans; address comparison `&T == &E` once references enter the subset |
| IR and backend | Lowering to SnBC; the transitional `snl build` binary is SnBC + bundled C VM; native backend in Snova (`native`): SnBC → aarch64 assembly, assembled by `as`/`ld`. N1 covers numeric operations; N2 covers strings, arrays, structs, printing, files, arguments and environment through the Snova runtime; N3 compiles the ordered compiler modules natively and reaches repeated assembly equality (`make bootstrap-native-self`); unit enum variants (`VARIANT` 42 without payload) and `match` (`IS_VARIANT` 43, literal, binding and wildcard arms, trap 52) run in the Snova executor and the native backend as tag 7 values | General imports and source-order independence; enum payloads, async/spawn, doubles and globals remain outside the native subset (doubles and globals are not lowered by the frontend either); N4 toolchain independence remains optional |
| Runtime | Snova facade for arguments, environment and I/O; SnBC validator; iterative SnBC executor in Snova that runs the compiler image; **native runtime in Snova** (`bootstrap/runtime/`, types `Primitive`, `System`, `Heap`, `Runtime`, `Text`, `Container`, `Ownership`, `Value`, `Host`): size-class heap with immediate release and `munmap`, ownership counts with static borrow elision, strong-cycle rejection, byte strings, arrays, objects, value equality, printing, files, arguments and environment; assembly only in the native `Primitive`/`System` stubs (ADR-0006) | Frontend borrow checker and weak references; faster copies for N3; the SnBC executor still uses the `/tmp` scratch file while it runs on the `snl` C VM (ADR-0004) |
| Library | `bootstrap/library/`: `BinarySearch`, `LinearSearch`, `Sorting`, `BinaryHeap`, `BinaryTree`, `IntMap` (static methods; SnBC and native, zero live blocks) | Instance-based API so the compiler can use it while `snl build` is the root (ADR-0007) |
| CLI | Input and output paths as arguments; internal bootstrap mode through `SNL_OUTPUT` | Flags, diagnostics and projects compatible with `snovac` |
| Self-compilation | The Snova seed compiles its source to SnBC; the Snova VM runs it to the same image; the native compiler repeats compilation to an identical assembly fixed point on the current host | Repeat the cycle after each extension and record hashes; clean-build reproducibility, Mach-O normalization and independent DDC remain separate gates |
| Full compatibility | Not demonstrated | `snovac` corpus with differential results and explicit gaps |

## Implementation rule

All new compiler, runtime and development tool code must be written in Snova.
C/C++ is not an alternative implementation. The installed `snl` seed is only
the transitional root used to obtain the first artifact; the chain advances
when the generated Snova compiler can compile its own revision and produce the
same artifact. Indispensable system calls stay behind small ABI contracts,
with no compiler logic outside Snova.

The compiler is the only product/publication piece of this project. Build
scripts and documentation are development support, not public toolchain
components.
