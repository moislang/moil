# ADR-0006 — Native runtime in Mois with ownership and a libSystem boundary

- **Status:** Accepted for slice N2 of ADR-0005; implemented (see "State")
- **Date:** 2026-11-21

## Context

Slice N1 of the native backend (ADR-0005) only translated the numeric subset
of SnBC. Strings, arrays, structs, printing and files still needed a runtime,
and the only one available was the C VM bundled by `moil build`. ADR-0003 only
allows assembly at OS/ABI boundaries. ADR-0004 left one provisional boundary
open: host strings have no bytes in the seed subset, so the Mois SnBC
executor converts them through a scratch file in `/tmp`.

Memory is a hard requirement: a program must never accumulate memory until it
exits. Every value has to be released as soon as nothing owns it. The model
follows the ownership contract in
`docs/architecture/compiler-modules-and-memory.md`: every heap value has an
explicit owner, a move transfers ownership, a borrow never outlives its owner,
cleanup happens exactly once, and strong cycles are rejected on mutation
paths.

## Decision

1. **Values.** Native code keeps the SnBC executor's tags (0 unit, 1 int,
   2 bool, 3 string, 4 array, 5 object, 6 null, 7 unit enum variant). A
   variant's payload is the address of its name in the constant pool, which
   interns names by content; it is never counted or freed, compares by
   payload and prints its name, as `moil run` does. Every value is a 16-byte
   slot `(payload, tag)`: operand stack entries, locals, arguments, array
   elements and object fields. Results return in `x0` (payload) and `x1`
   (tag). SnBC is dynamically typed (`ADD` serves both ints and strings,
   `PRINT` serves every type), so the tag has to travel with the value.
2. **Runtime source.** The runtime is Mois source in `bootstrap/runtime/`,
   one type per file (ADR-0007): `Primitive`, `System`, `Heap`, `Runtime`,
   `Text`, `Container`, `Ownership`, `Value` and `Host`. In `native` mode the
   compiler appends these files to the program source (`appendNativeRuntime`
   in `SourceJoin.snl`) and compiles everything into one SnBC image. The
   backend then translates the runtime with the same code path it uses for
   the program.
3. **Reserved types.** The runtime type names are reserved in native
   programs. The backend finds the methods it calls by their `Type.method`
   name (role table in `NativeRoles.snl`). Methods of runtime types do not
   count toward the 256-frame program depth limit, and they are not
   instrumented for ownership: they manage raw addresses themselves, like
   moisc's runtime layer.
4. **Assembly boundary.** `Primitive` and `System` declare native methods
   (`@Native`, no body). The backend replaces each one with an aarch64 stub
   (`NativeBoundary.snl`):
   - `Primitive`: `state`, `load`, `store`, `loadByte`, `storeByte`, and
     `tagged`, which retags a payload;
   - `System`: `write`, `read`, `open` (the variadic `mode` goes on the
     stack, as Darwin arm64 requires), `close`, `map` (`_mmap`), `unmap`
     (`_munmap`) and `exit`.

   The other boundary code is `_main`, which stores `argc/argv/envp` in a
   256-byte state block, calls `main` and hands its int result to
   `Runtime.finish`. These stubs and `_main` are the only generated code
   that calls libSystem.
5. **Heap with release** (`Heap`, `Heap.snl`). Every block has a 16-byte
   header `[owner count][size class]`.
   - Small blocks (up to 64 KiB with the header) use 12 power-of-two classes.
     A freed block goes onto its class's free list and is reused by the next
     allocation of that class.
   - Large blocks get their own `mmap` and go back to the kernel with
     `munmap` when freed.
   - Temporary buffers (C paths, file reads, equality scratch, array
     growth) are freed by the runtime before it returns.
6. **Ownership in the backend** (`NativeOwnership`, runtime type `Ownership`).
   Locals, operand-stack temporaries, object fields and array elements are
   owners: each one holds one count in the block header. When the last owner
   goes away, `Ownership.destroy` runs exactly once, releases the children
   and frees the blocks.
   - **Moves.** Call arguments move into the callee, which releases its
     parameters and locals on `RETURN`. The elements of `NEW_ARRAY` and
     `NEW_OBJECT` and the element of `ARRAY_PUSH` move into the container.
     `ARRAY_POP` clears the removed slot and transfers its owner to the result.
   - **Borrows.** The backend keeps a static model of the operand stack: every
     slot is either an owner or a borrow of a local. `LOAD_LOCAL` produces a
     borrow and takes no count, because the local keeps the value alive. A
     borrow becomes an owner (one retain) only where it escapes or where its
     source could change: a store into a local, field or array, a call
     argument, a return value, a value that crosses a jump (all slots are
     owners at jump targets, so every incoming edge agrees), or a value held
     while its source local is overwritten. The other consumers (field and
     index reads, `ARRAY_LEN`, `PRINT`, comparisons, runtime calls) read the
     borrow without counting, and release owned operands after use. `ARRAY_POP`
     moves the element owner out before releasing the consumed array operand.
   - **Strong cycles.** `SET_FIELD` with an array or object value and
     `ARRAY_PUSH` reject a store that would make the target reachable from
     the stored value: `runtime error: strong reference cycle rejected for
     opcode N`, status 70. The heap stays acyclic, so every value reaches zero
     owners.
   - **Constants.** Constants in `__TEXT,__const` have a negative count and
     are never counted or freed.
7. **Layouts** (a contract shared between `Container.snl` and
   `NativeValueEmitter.snl`; each payload follows the header):
   - string: `[length:8][bytes]`;
   - array: `[length:8][capacity:8][data:8]`, with 16-byte elements in their
     own block; capacity doubles when full, and the old data block is freed;
   - object: `[field count:8][fields of 16 bytes]`.
8. **Inline code vs runtime calls.** Int/bool arithmetic and comparison,
   jumps, locals, `GET_FIELD`, `SET_FIELD` (non-container values),
   `GET_INDEX`, `ARRAY_LEN`, `ARRAY_POP`, `NEG`, `NOT`, retain and release are inline.
   Value equality, concatenation, type errors, allocation, `ARRAY_PUSH`,
   container stores, `PRINT`, files, arguments and environment call the Mois
   runtime. Their semantics and messages copy the Mois SnBC executor, which
   acts as the differential oracle.
9. **Memory evidence.** `Runtime.finish` counts live blocks, live bytes
   and peak live bytes. With `MOIS_MEMORY_REPORT` set, it writes them to
   stderr. The gate requires zero live blocks at exit and the same peak for
   20 000 and 160 000 loop iterations.

## The string→bytes boundary of ADR-0004

On the native path, a host string is bytes from the start: arguments and
environment variables are copied from `argv`/`envp`, and files are read with
`_read`. Equality and concatenation compare and copy bytes, and nothing goes
through `/tmp`. The `vmHostText` fixture, which exercises exactly that case,
runs natively. Evidence: the generated assembly does not mention `/tmp`, and
the executable imports only the libSystem symbols listed above.

The Mois SnBC executor keeps the scratch file while it runs on the C VM of
`moil build`. That host still has no string→bytes primitive. The executor stops
needing the file once the compiler itself is compiled by the native backend
(N3).

## Intentional divergences from the SnBC executor

- Strong cycles are rejected (the executor allows them).
- `read_bytes` of a missing file returns an empty array. The `moil` host aborts
  with `error: cannot read`.
- Out of memory ends the program with `runtime error: out of memory`
  (status 70).
- The program's exit status is the `_exit` byte (`status & 255`), as for any
  process.

## Consequences

- There is no garbage collector and none is needed for acyclic data: release
  is deterministic and immediate. Cyclic structures need weak references,
  which are not in the subset.
- Each executable carries the whole runtime (about 20k lines of assembly for
  `hello`). Eliminating dead code is a future optimization.
- Byte copies go through primitive calls, and returning functions release
  locals through a runtime loop; both are slow paths. Inline primitives and
  per-slot inline release are performance proposals for N3. They are not
  adopted yet.
- Ownership analysis lives in the backend, over SnBC stack slots. The
  frontend does not reject use-after-move or aliasing errors yet. A frontend
  borrow checker with the moisc rules (MOISL0240–0251) is a separate
  proposal.
- Opcodes outside the subset (enum variants, match, async/spawn, doubles,
  globals) still fail with `unsupported opcode for native backend: N`.

## State

Gate `make bootstrap-native`:
- the numeric fixtures match the exit status of the Mois executor and
  `moil run-snbc`;
- `hello`, `vmCalls`, `vmComposite`, `vmEquality`, `vmStackOverflow`,
  `nativeHostIo` and `nativeMemory` match the Mois executor's stdout and
  exit status;
- `vmHostText` matches its fixed expected output and the file it writes;
- every program that ends normally leaves zero live blocks;
- `nativeMemory` keeps the same peak (1088 bytes) for 8 times more work;
- `nativeCycle` is rejected with status 70;
- `nativeUnsupported` (an enum variant) fails with opcode 42.

Evidence is recorded in `docs/roadmap/evidence.md`.

## Reopen when

Weak references or cyclic data enter the subset, another target is added,
the frontend gains a borrow checker that lets the backend drop dynamic counts,
or N3 measurements call for faster copies and release.
