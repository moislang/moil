---
name: self-hosting-research
description: Pesquisa bootstrap de compiladores e transforma literatura primária em decisões aplicáveis ao compilador Snovalang.
---

# Pesquisa de compiladores self-hosted

## Use quando

Avaliar bootstrap, ponto fixo, cadeia de confiança, DDC, reprodutibilidade ou uma arquitetura alternativa de seed.

## Fontes-base

Consulte `docs/research/compiler-literature.md` antes de pesquisar novamente. Comece pelos artigos do pnut/SLE 2024 e DDC de Wheeler, documentação GCC de bootstrap e material LLVM/Appel para fases do compilador.

## Procedimento

1. Enuncie a pergunta de engenharia e os critérios de comparação.
2. Priorize artigos revisados por pares, artefatos publicados pelos autores, documentação oficial e livros/autores originais.
3. Separe resultados reportados pela fonte de inferências para Snovalang.
4. Extraia condições de validade, limites e dependências da ferramenta; evite resumir apenas o abstract.
5. Compare alternativas com custo de seed, recursos necessários, dependência do host, auditabilidade e força da evidência.
6. Recomende decisão pequena, reversível e com probe ou ADR para validar as incertezas.
7. Atualize a bibliografia e o ADR afetado com links diretos e data de consulta quando uma fonte nova sustentar uma decisão.

## Checklist

- [ ] Fonte primária e ligação verificável?
- [ ] Evidência separada de inferência?
- [ ] Premissas aplicáveis ao `snl` instalado foram medidas?
- [ ] Self-hosting, reprodutibilidade, ponto fixo e DDC não foram confundidos?
- [ ] A recomendação mantém Snovalang como linguagem de implementação?
