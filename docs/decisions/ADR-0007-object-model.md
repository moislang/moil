# ADR-0007 — Object model for the compiler and the native runtime

- **Status:** Accepted; applied to the native backend and the native runtime
- **Date:** 2026-11-21

## Context

The compiler is to be built with object-oriented design: types instead of
name prefixes, with each former prefix (`snova`, `snovaRuntime`,
`snovaPrimitive`) becoming a type. The reference compiler already models its
builtin runtime as `class Runtime` with `@Native public static method`
declarations (`../snovac/builtin/runtime`).

Compiler source must be accepted by two compilers: the Snova seed (fixed
point) and `snl build` v0.3.0, the transitional root that produces the
compiler executable. Probes recorded in `docs/roadmap/evidence.md` showed
what each one accepts.

The seed already supported classes, fields, instance methods with implicit
field access, sibling calls and positional constructors `Type(args)`. It did
not support `static` or annotations.

`snl build` v0.3.0, the root, behaves as follows:
- **Accepts:** method calls on locals created by a constructor, on typed
  parameters and on siblings, and classes without fields.
- **Rejects, with `invalid SnBC unit for native compilation`:** any static
  method, even one without parameters.
- **Rejects, with `cannot lower call to SnBC`:** method calls whose receiver
  is a field, directly or through a local alias, and calls on objects created
  with a literal `Type { ... }`.
- **Intercepts:** methods named like array builtins (`push`, `pop`, `len`,
  `get`, ...) as array operations (`push expects an array`).
- **Releases an array** when a field holding it is reassigned, so an array
  shared by two fields leaves the other field dangling. Moving a value out of
  a field is rejected (SNOVA0251).

## Decision

1. **Seed extension.** The seed accepts the `static` modifier (no implicit
   self; the arity has no `+1`) and skips `@Annotation` tokens; a bodyless
   method is native. `Type.method(...)` requires a static method;
   `object.method(...)` requires an instance method; inside an instance
   method an unqualified call may reach a static sibling. A static method
   body has no instance, so it calls siblings through its type. Fixtures:
   `staticMethods` (valid) and `invalidStaticCall` (rejected).
2. **Native runtime: one type per responsibility, static methods.** The
   types are `Primitive` and `System` (native boundary), `Heap`, `Text`,
   `Container`, `Ownership`, `Value`, `Host` and `Runtime`. The seed and the
   native backend compile them; `snl build` never does, so static methods
   are allowed. These type names are reserved in native programs, and the
   backend finds runtime methods by their `Type.method` names (ADR-0006).
3. **Compiler code: instance-based objects** while `snl build` v0.3.0 is
   the root:
   - objects are created with constructors and kept in locals;
   - collaborators travel as typed parameters, never as receivers held in
     fields;
   - no static methods;
   - no method named like an array builtin;
   - no array shared between two fields.
   The native backend follows this model: `NativeImage`, `NativeRoles`,
   `NativeAssembly`, `NativeSlot`, `NativeOwnership`, `NativeValueEmitter`,
   `NativeInstructionEmitter`, `NativeBoundary` and `NativeBackend`.
4. **Naming.** Types are PascalCase, as in snovac (`Runtime`, `Box`).
   Functions, methods, variables and source files stay camelCase. Existing
   lowercase structs of the frontend keep their names until they are
   migrated.

## Consequences

- The frontend (lexer, parser, emitters) is still procedural over
  `compilerState`/`compilerContext`. Migrating it to objects follows the
  rules above, in small steps that keep the fixed point.
- The data-structure library in `bootstrap/library/` uses static methods.
  It serves programs compiled by the Snova compiler (SnBC and native), but
  not the compiler itself, until the library has an instance-based API or
  the compiler is built natively (N3).
- Once the native backend builds the compiler (N3), the root's restrictions
  stop applying, and the rules can be relaxed through a new ADR.

## Reopen when

The root changes (another `snl` version, or the native compiler replaces it),
or the frontend migration needs a feature that these rules forbid.
