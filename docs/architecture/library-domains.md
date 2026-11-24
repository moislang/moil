# Library domains and aggregates

The Mois library is organized by domain responsibility. A folder contains a
small cohesive package instead of acting as a flat dumping ground. Package
names follow the directory tree, so source layout and import paths stay
aligned.

```text
bootstrap/library/
├── algorithms/
│   ├── search/       BinarySearch, LinearSearch
│   └── sorting/      Sorting
└── collections/
    ├── array/        IntArray, IntCell
    ├── heap/         BinaryHeap
    ├── map/          IntMap, MapEntry
    └── tree/         BinaryTree, TreeNode
```

## Domain model

- `BinarySearch`, `LinearSearch`, and `Sorting` are stateless domain services
  with instance APIs.
- `IntArray` owns its logical size and its cell storage. `IntCell` encapsulates
  each mutable integer slot.
- `BinaryHeap` is a collection aggregate that owns an `IntArray` and enforces
  the heap ordering through its public operations.
- `BinaryTree` is the tree aggregate root. It owns a node arena, while
  `TreeNode` encapsulates node state. Links are arena indexes, which keeps the
  structure acyclic and avoids nullable object references.
- `IntMap` is the map aggregate root. It owns bucket heads and an entry arena;
  `MapEntry` encapsulates each chain entry. Keys and payloads are integer
  values in this first library slice.

Clients create aggregates with positional constructors and call their public
methods. Mutable state is held in non-public fields, and the internal entities
are not shared between aggregates. The transitional
root cannot invoke methods directly on fields or array elements, so aggregate
methods pass an entity or owned collaborator to a private helper with a typed
parameter. That constraint stays at the implementation boundary; it does not
change the domain API.

Package examples:

- `mois.library.algorithms.search.BinarySearch`
- `mois.library.collections.tree.BinaryTree`
- `mois.library.collections.map.IntMap`

The source assembly lists in `Makefile` preserve dependency order for the
bootstrap compiler and fixtures. Once project imports are the normal library
consumption path, clients should import the package or type they use instead
of relying on a generated joined source unit.
