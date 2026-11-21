# Fluxo de desenvolvimento

Este fluxo organiza o trabalho antes de cada feature e define como manter o plano sincronizado com a implementação.

## Antes de implementar

1. Leia `README.md`, regras em `.claude/rules/` e a skill relevante.
2. Confirme a raiz atual e não escreva em `../snovac`.
3. Leia o ADR e a fase aplicável; confira `docs/roadmap/evidence.md`.
4. Para dependência do compilador hospedeiro, execute uma sonda isolada, anote versão, comando e resultado.
5. Especifique subset, sintaxe, semântica, erros, fixtures positivas/negativas e critério de conclusão.
6. Planeje um corte vertical pequeno que o compilador anterior consiga construir.

## Durante a implementação (futuro)

- Mantenha uma declaração por arquivo quando isso melhorar localização e revisão; evite monólitos e use tipos/retornos explícitos.
- Use `camelCase` em funções, classes, structs, interfaces e nomes de arquivos-fonte.
- Código do compilador/runtime em `.snl`/`.sns`; assembly só na fronteira aprovada.
- Não avance recursos do subset sem suporte no compilador predecessor.
- Registre limitações observadas e atualize os diagramas/ADRs apenas quando a arquitetura mudar.

## Fechamento de marco

1. Execute apenas os checks definidos para o marco e reporte comandos/resultados.
2. Compare comportamento com referência quando aplicável.
3. Atualize `evidence.md`, matriz do subset e status do roadmap.
4. Confirme que nenhuma mudança alcançou `../snovac`.
5. Diferencie build, teste, execução nativa, cross-compile, reprodução e DDC.

## Pull requests

PRs futuros devem declarar fase/marco, subset afetado, riscos, evidência, limitações e plano de reversão. Mudanças de arquitetura requerem ADR atualizado. Mudanças de linguagem exigem exemplos aceitos e rejeitados. Falha de um alvo não pode ser ocultada por sucesso em outro.
