---
name: compiler-frontend
description: Projetar ou implementar lexer, parser, AST e diagnósticos compatíveis com a linguagem Snovalang.
---

# Frontend de compilador

## Princípios

- A especificação executável do compilador de referência é observada com fixtures, sem editar `../snovac`.
- Lexer, parser e AST têm contratos e testes de fase separados; erros mantêm código, span e posição de origem.
- Preserve determinismo e comportamento UTF-8/bytes conforme a especificação medida.
- Parser escolhe técnica simples que caiba no subset do estágio; não introduza framework/gerador antes de justificativa.
- O código-fonte do frontend deve continuar dentro do subconjunto compilável pelo predecessor.

## Procedimento

1. Defina tokens, escapes, comentários, precedência, associatividade, recuperação de erros e AST mínima.
2. Crie fixtures de fronteira: entrada vazia, fim de arquivo, unicode, tokens inválidos, precedência e nesting.
3. Compare lex/parse/dump e diagnósticos com a referência; classifique as diferenças antes de mudar o contrato.
4. Só depois expanda para declarações, tipos, patterns, módulos ou sintaxe contextual.
5. Registre mudanças de linguagem na matriz de subset e aplique gate de bootstrap.

## Revisão

Verifique escapes, overflow numérico, offsets, mensagens estáveis, recuperação após erro e se fixtures cobrem parse válido e inválido.
