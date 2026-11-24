# Compiler architecture rules

- This checkout is the write boundary. Treat `../moisc` as a read-only reference.
- The goal is to implement the compiler and runtime in Moislang. Do not migrate to C for convenience.
- Assembly is allowed only in the minimal seed/ABI/OS boundary when a probe proves there is no Moislang alternative. Document every boundary.
- The predecessor must compile the next stage's code. Never introduce a language feature into the compiler without updating the subset matrix and fixtures.
- Confirm the version and capabilities of the installed `moil` with probes; do not trust historical notes or the plan as current evidence.
- Separate lexer, parser, semantics, IR, backend, runtime and driver through explicit contracts; avoid language rules hidden in the driver.
- Use typed structures and returns; diagnostics are data with a code and a span. Keep symbols, errors and artifacts deterministic.
- Model the compiler with objects (ADR-0007). Types and source files are PascalCase; functions, methods and variables are camelCase. Use types instead of name prefixes.
- While `moil build` v0.3.0 is the root, compiler code creates objects with constructors, calls methods only on locals, parameters or siblings (never on a field), has no static methods, does not name methods like array builtins (`push`, `pop`, `len`, `get`) and never shares one array between two fields.
- Do not claim self-hosting, fixed point, reproducibility or DDC without the matching recorded evidence.
- A feature requires a specification, a valid case, an invalid case and a build gate by the predecessor.
- Do not add a dependency, target, exceptions, concurrency or an advanced GC to the first vertical slice without an updated ADR/roadmap. Memory is released deterministically through ownership (ADR-0006).
