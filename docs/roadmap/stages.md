# Roadmap de desenvolvimento

O roadmap é uma sequência de gates. Não se inicia a fase seguinte enquanto a evidência mínima da anterior não estiver registrada. Datas e estimativas ficam fora deste plano até existir medição real.

| Fase | Entrega | Gate para avançar |
|---|---|---|
| P0 — Descoberta | Inventário do `snl` instalado, versão, host, interfaces de arquivos/processos, sintaxe e limites do seed. Sondas pequenas e reproduzíveis. | Cada capacidade usada pelo seed tem probe e resultado; limitações e versão são registradas. Nenhuma dependência implícita de `snl run`. |
| P1 — Contratos | Especificação do primeiro subconjunto, formatos de entrada/saída, diagnósticos, layout inicial e baseline do compilador de referência. | Casos aceitos e rejeitados definidos; critérios de equivalência automatizáveis. |
| P2 — Hello vertical | Seed mínimo em Snovalang/subconjunto confirmado que gera um programa host simples; assembly mínimo somente se indispensável. | Build limpo, execução, código de saída e stdout verificados; seed recompilável pelo procedimento documentado. |
| P3 — Primeiro compilador | Lexer, parser mínimo, representação intermediária e backend para um alvo; compila exemplos e subset de si mesmo. | Diferenciais positivos/negativos, erros com posições, semântica definida para cada feature implementada. |
| P4 — Crescimento incremental | Estender subset em pequenos marcos: dados/coleções, funções e chamadas, tipos, módulos e runtime conforme dependências reais. | Para cada extensão: probe da ferramenta, spec, fixtures, diferencial e build do compilador anterior. |
| P5 — Bootstrap | Compilador anterior gera novo compilador; builds repetidos com entradas/toolchain fixadas. | Cadeia registrada, artefatos comparados, hashes e diferenças explicados. |
| P6 — Compatibilidade | Expandir gradualmente CLI, projetos, builtins, diagnósticos e corpus de referência. | Matriz de compatibilidade atualizada; comportamento não suportado explicitamente listado. |
| P7 — Plataformas adicionais | Portar backend e ABI após host estável. | Cada alvo tem assemble/link/run quando toolchain disponível; limitações distinguem compilação de execução. |
| P8 — DDC e manutenção | Raiz independente, cadeia de confiança e fluxo de atualização do seed. | Root-of-trust explícita; comparação independente documentada. Se não for possível, DDC fica marcado como não comprovado. |

## Estado atual

O seed Snova foi integrado em `bootstrap/src/`. Há evidência local de check,
build nativo, execução de um programa gerado, diagnósticos positivos/negativos,
compilação do source pelo seed e igualdade de duas imagens SnBC. Isso fecha um
ciclo inicial restrito; não fecha compatibilidade nem substitui `snovac`. A sequência de expansão e os limites estão em
[`subset.md`](subset.md) e os comandos reproduzíveis em `Makefile`.

## Regra de crescimento

O subset do compilador `N+1` precisa estar contido no subset que o compilador `N` consegue compilar. Uma feature nova é entregue nesta ordem: probe → especificação → fixture → implementação mínima → diferencial → build do próximo estágio. Evitar saltos para dezenas de features antes de fechar um ciclo completo.

## Fora do primeiro marco

Multi-target, collector avançado, exceções com unwind, concorrência, compatibilidade total de CLI e DDC não são requisitos do primeiro hello vertical. Reintroduzi-los exige motivação e gate próprios.

## Registro de execução

Cada fase deve atualizar `docs/roadmap/evidence.md` com commit/revisão, host, versão do compilador, comando, resultado, artefatos e limitações. Não registrar intenção como evidência concluída.
