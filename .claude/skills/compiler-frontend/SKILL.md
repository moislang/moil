---
name: compiler-frontend
description: Design or implement a lexer, parser, AST and diagnostics compatible with the Moislang language.
---

# Compiler frontend

## Principles

- The executable specification of the reference compiler is observed through fixtures, without editing `../moisc`.
- Lexer, parser and AST have separate contracts and phase tests; errors keep a code, a span and the source position.
- Keep determinism and UTF-8/byte behavior as measured in the specification.
- The parser uses a simple technique that fits the stage's subset; do not introduce a framework/generator without justification.
- Frontend source must stay inside the subset the predecessor can compile.

## Procedure

1. Define tokens, escapes, comments, precedence, associativity, error recovery and the minimal AST.
2. Create boundary fixtures: empty input, end of file, unicode, invalid tokens, precedence and nesting.
3. Compare lex/parse/dump and diagnostics with the reference; classify differences before changing the contract.
4. Only then expand to declarations, types, patterns, modules or contextual syntax.
5. Record language changes in the subset matrix and apply the bootstrap gate.

## Review

Check escapes, numeric overflow, offsets, stable messages, recovery after errors and whether fixtures cover valid and invalid parses.
