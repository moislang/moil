# ADR-0003 — Snovalang como linguagem principal; assembly nas fronteiras

- **Status:** Aceito
- **Data:** 2026-11-21

## Contexto

O objetivo é demonstrar self-hosting em Snovalang. Ao mesmo tempo, a primeira versão pode não expor primitivas para iniciar o processo, chamar o assembler/linker ou alcançar syscalls/ABI.

## Decisão

Implementar compilador, runtime e ferramentas em Snovalang quando as capacidades confirmadas permitirem. Permitir assembly somente em fronteiras de host documentadas: bootstrap mínimo e chamadas ABI/OS sem interface equivalente. Cada símbolo de fronteira precisa de contrato e teste de integração. Não permitir C como atalho de implementação.

## Consequências

- O inventário de primitivas disponíveis precede o desenho do seed.
- O conjunto de assembly depende de cada plataforma e deve ser minimizado.
- O compilador, o runtime e as ferramentas específicas do produto são escritos em Snova; C/C++ não são linguagens de implementação alternativas.
- A toolchain instalada é uma raiz transitória enquanto o compilador Snova não consegue produzir e executar seu próprio artefato sem o runtime anterior.
- Uma necessidade de C exige proposta de decisão separada e justificativa de impossibilidade técnica em Snovalang/assembly.

O estado inicial ainda usa o runtime fornecido pelo `snl` para executar o SnBC
gerado. Isso é dependência de bootstrap, não implementação C do compilador
neste repositório; removê-la é um gate explícito da migração.

## Reabrir quando

Uma interface de runtime Snovalang nativa tornar desnecessária uma fronteira assembly ou quando evidência demonstrar que uma alternativa é necessária para a cadeia de bootstrap.
