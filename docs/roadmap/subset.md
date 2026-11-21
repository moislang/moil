# Compiler subset

This matrix separates implemented capability from compatibility with
`snovac`. A row only advances after compiler Snova source uses the feature and
a previous stage can compile it.

| Area | Current seed | Next gate |
|---|---|---|
| Compiler sources | camelCase `.snl` modules; project build; internal assembly of its own sources | Resolve imports and compile general projects directly in the Snova compiler |
| Frontend | Subset lexer/parser with phase and line diagnostics | Stable diagnostics with spans and a versioned differential against the reference |
| Semantics | Local resolution needed by the subset; static types of literals, locals, parameters and fields; warning `SNW0001` for `==`/`!=` between known, different types (does not stop compilation) | Compatible types and diagnostics by milestones; full spans; address comparison `&T == &E` once references enter the subset |
| IR and backend | Lowering to SnBC; the `snl build` binary is SnBC + bundled C VM; native backend in Snova (`native`): SnBC → aarch64 assembly, assembled by `as`/`ld`. N1 covers the numeric subset; N2 covers strings, arrays, structs, printing, files, arguments and environment through the Snova runtime | N3: compile the compiler natively and repeat the compilation (ADR-0005); enum variants, match and async remain unsupported natively |
| Runtime | Snova facade for arguments, environment and I/O; SnBC validator; iterative SnBC executor in Snova that runs the compiler image; **native runtime in Snova** (`bootstrap/runtime/`): bump allocator over `mmap`, byte strings, arrays, objects, value equality, printing, files, arguments and environment; assembly only in primitive stubs and `_write`/`_read`/`_open`/`_close`/`_mmap`/`_exit` (ADR-0006) | Memory reclamation and faster copies for N3; stderr; the SnBC executor still uses the `/tmp` scratch file while it runs on the `snl` C VM (ADR-0004) |
| CLI | Input and output paths as arguments; internal bootstrap mode through `SNL_OUTPUT` | Flags, diagnostics and projects compatible with `snovac` |
| Self-compilation | The Snova seed compiles its source to SnBC; the next image matches | Repeat the cycle after each extension and record the hashes |
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
